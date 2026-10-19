module deltablue;

import benchmark;
import memory;
import som.error;
import som.identity_dictionary;
import som.vector;

private enum Direction {
    forward,
    backward,
    none,
}

private struct Sym {
    private uint hash;

    uint customHash() const {
        return hash;
    }
}

private struct Strength {
    __gshared static Sym absoluteStrongest = Sym(0);
    __gshared static Sym required_ = Sym(1);
    __gshared static Sym strongPreferred = Sym(2);
    __gshared static Sym preferred = Sym(3);
    __gshared static Sym strongDefault = Sym(4);
    __gshared static Sym default_ = Sym(5);
    __gshared static Sym weakDefault = Sym(6);
    __gshared static Sym absoluteWeakest_ = Sym(7);

    private static IdentityDictionary!(Sym*, int) strengthTable;
    private static IdentityDictionary!(Sym*, Strength*) strengthConstant;
    private static Strength* absoluteWeakestStrength;
    private static Strength* requiredStrength;

    private int arithmeticValue;
    private Sym* symbolicValue;

    this(Sym* symbolicValue) {
        arithmeticValue = strengthTable.at(symbolicValue);
        this.symbolicValue = symbolicValue;
    }

    bool sameAs(Strength* s) const {
        return arithmeticValue == s.arithmeticValue;
    }

    bool stronger(Strength* s) const {
        return arithmeticValue < s.arithmeticValue;
    }

    bool weaker(Strength* s) const {
        return arithmeticValue > s.arithmeticValue;
    }

    Strength* strongest(Strength* s) {
        return s.stronger(&this) ? s : &this;
    }

    Strength* weakest(Strength* s) {
        return s.weaker(&this) ? s : &this;
    }

    int getArithmeticValue() const {
        return arithmeticValue;
    }

    static Strength* of(Sym* strength) {
        return strengthConstant.at(strength);
    }

    static Strength* absoluteWeakest() {
        return absoluteWeakestStrength;
    }

    static Strength* required() {
        return requiredStrength;
    }

    private static IdentityDictionary!(Sym*, int) createStrengthTable() {
        version (ManualMemory)
            auto table = make!(IdentityDictionary!(Sym*, int));
        else
            auto table = new IdentityDictionary!(Sym*, int);
        table.atPut(&absoluteStrongest, -10_000);
        table.atPut(&required_, -800);
        table.atPut(&strongPreferred, -600);
        table.atPut(&preferred, -400);
        table.atPut(&strongDefault, -200);
        table.atPut(&default_, 0);
        table.atPut(&weakDefault, 500);
        table.atPut(&absoluteWeakest_, 10_000);
        return table;
    }

    private static IdentityDictionary!(Sym*, Strength*) createStrengthConstants() {
        version (ManualMemory)
            auto constants = make!(IdentityDictionary!(Sym*, Strength*));
        else
            auto constants = new IdentityDictionary!(Sym*, Strength*);
        auto keys = strengthTable.getKeys();
        keys.forEach((key) {
            version (ManualMemory)
                constants.atPut(key, makePtr!Strength(key));
            else
                constants.atPut(key, new Strength(key));
        });
        version (ManualMemory) dispose(keys);
        return constants;
    }

    static void initializeConstants() {
        strengthTable = createStrengthTable();
        strengthConstant = createStrengthConstants();
        absoluteWeakestStrength = of(&absoluteWeakest_);
        requiredStrength = of(&required_);
    }

    static void releaseConstants() {
        version (ManualMemory) {
            version (ManualMemory) dispose(strengthTable);
            strengthConstant.destroyValues();
            version (ManualMemory) dispose(strengthConstant);
            absoluteWeakestStrength = null;
            requiredStrength = null;
        }
    }
}

private abstract class AbstractConstraint : TrackedObject {
    protected Strength* strength;

    this(Sym* strength) {
        this.strength = Strength.of(strength);
    }

    Strength* getStrength() {
        return strength;
    }

    bool isInput() {
        return false;
    }

    final void addConstraint(Planner* planner) {
        addToGraph();
        planner.incrementalAdd(this);
    }

    final void destroyConstraint(Planner* planner) {
        if (isSatisfied())
            planner.incrementalRemove(this);
        removeFromGraph();
    }

    final bool inputsKnown(int mark) {
        return !inputsHasOne((v) =>
            !(v.getMark() == mark || v.getStay() || v.getDeterminedBy() is null));
    }

    final AbstractConstraint satisfy(int mark, Planner* planner) {
        AbstractConstraint overridden;

        chooseMethod(mark);

        if (isSatisfied()) {
            inputsDo((in_) { in_.setMark(mark); });

            Variable out_ = getOutput();
            overridden = out_.getDeterminedBy();
            if (overridden !is null)
                overridden.markUnsatisfied();
            out_.setDeterminedBy(this);
            if (!planner.addPropagate(this, mark))
                throw new SomError("Cycle encountered");
            out_.setMark(mark);
        } else {
            overridden = null;
            if (strength.sameAs(Strength.required()))
                throw new SomError("Could not satisfy a required constraint");
        }
        return overridden;
    }

    abstract bool isSatisfied();
    abstract void addToGraph();
    abstract void removeFromGraph();
    abstract Direction chooseMethod(int mark);
    abstract void execute();
    abstract void inputsDo(scope void delegate(Variable) fn);
    abstract bool inputsHasOne(scope bool delegate(Variable) fn);
    abstract void markUnsatisfied();
    abstract Variable getOutput();
    abstract void recalculate();
}

private final class Variable : TrackedObject {
    private int value;
    private Vector!AbstractConstraint* constraints;
    private AbstractConstraint determinedBy;
    private int mark;
    private Strength* walkStrength;
    private bool stay = true;

    this() {
        version (ManualMemory)
            constraints = makePtr!(Vector!AbstractConstraint)(2);
        else
            constraints = new Vector!AbstractConstraint(2);
        walkStrength = Strength.absoluteWeakest();
    }

    version (ManualMemory) ~this() {
        version (ManualMemory) dispose(constraints);
    }

    static Variable value_(int aValue) {
        version (ManualMemory)
            auto v = make!Variable;
        else
            auto v = new Variable;
        v.setValue(aValue);
        return v;
    }

    void addConstraint(AbstractConstraint c) {
        constraints.append(c);
    }

    Vector!AbstractConstraint* getConstraints() {
        return constraints;
    }

    AbstractConstraint getDeterminedBy() {
        return determinedBy;
    }

    void setDeterminedBy(AbstractConstraint c) {
        determinedBy = c;
    }

    int getMark() const {
        return mark;
    }

    void setMark(int markValue) {
        mark = markValue;
    }

    void removeConstraint(AbstractConstraint c) {
        constraints.remove(c);
        if (determinedBy is c)
            determinedBy = null;
    }

    bool getStay() const {
        return stay;
    }

    void setStay(bool v) {
        stay = v;
    }

    int getValue() const {
        return value;
    }

    void setValue(int value) {
        this.value = value;
    }

    Strength* getWalkStrength() {
        return walkStrength;
    }

    void setWalkStrength(Strength* strength) {
        walkStrength = strength;
    }
}

private abstract class BinaryConstraint : AbstractConstraint {
    protected Variable v1;
    protected Variable v2;
    protected Direction direction = Direction.none;

    this(Variable var1, Variable var2, Sym* strength, Planner*) {
        super(strength);
        v1 = var1;
        v2 = var2;
    }

    override bool isSatisfied() {
        return direction != Direction.none;
    }

    override void addToGraph() {
        v1.addConstraint(this);
        v2.addConstraint(this);
        direction = Direction.none;
    }

    override void removeFromGraph() {
        v1.removeConstraint(this);
        v2.removeConstraint(this);
        direction = Direction.none;
    }

    override Direction chooseMethod(int mark) {
        if (v1.getMark() == mark) {
            if (v2.getMark() != mark && strength.stronger(v2.getWalkStrength())) {
                direction = Direction.forward;
                return direction;
            }
            direction = Direction.none;
            return direction;
        }

        if (v2.getMark() == mark) {
            if (v1.getMark() != mark && strength.stronger(v1.getWalkStrength())) {
                direction = Direction.backward;
                return direction;
            }
            direction = Direction.none;
            return direction;
        }

        if (v1.getWalkStrength().weaker(v2.getWalkStrength())) {
            if (strength.stronger(v1.getWalkStrength())) {
                direction = Direction.backward;
                return direction;
            }
            direction = Direction.none;
            return direction;
        }
        if (strength.stronger(v2.getWalkStrength())) {
            direction = Direction.forward;
            return direction;
        }
        direction = Direction.none;
        return direction;
    }

    override void inputsDo(scope void delegate(Variable) fn) {
        if (direction == Direction.forward)
            fn(v1);
        else
            fn(v2);
    }

    override bool inputsHasOne(scope bool delegate(Variable) fn) {
        if (direction == Direction.forward)
            return fn(v1);
        return fn(v2);
    }

    override void markUnsatisfied() {
        direction = Direction.none;
    }

    override Variable getOutput() {
        return direction == Direction.forward ? v2 : v1;
    }

    override void recalculate() {
        Variable in_;
        Variable out_;
        if (direction == Direction.forward) {
            in_ = v1;
            out_ = v2;
        } else {
            in_ = v2;
            out_ = v1;
        }

        out_.setWalkStrength(strength.weakest(in_.getWalkStrength()));
        out_.setStay(in_.getStay());

        if (out_.getStay())
            execute();
    }
}

private abstract class UnaryConstraint : AbstractConstraint {
    protected Variable output;
    protected bool satisfied;

    this(Variable v, Sym* strength, Planner*) {
        super(strength);
        output = v;
    }

    override bool isSatisfied() {
        return satisfied;
    }

    override void addToGraph() {
        output.addConstraint(this);
        satisfied = false;
    }

    override void removeFromGraph() {
        if (output !is null)
            output.removeConstraint(this);
        satisfied = false;
    }

    override Direction chooseMethod(int mark) {
        satisfied = (output.getMark() != mark) && strength.stronger(output.getWalkStrength());
        return Direction.none;
    }

    override void inputsDo(scope void delegate(Variable)) {
    }

    override bool inputsHasOne(scope bool delegate(Variable)) {
        return false;
    }

    override void markUnsatisfied() {
        satisfied = false;
    }

    override Variable getOutput() {
        return output;
    }

    override void recalculate() {
        output.setWalkStrength(strength);
        output.setStay(!isInput());

        if (output.getStay())
            execute();
    }
}

private final class EditConstraint : UnaryConstraint {
    this(Variable v, Sym* strength, Planner* planner) {
        super(v, strength, planner);
        addConstraint(planner);
    }

    override bool isInput() {
        return true;
    }

    override void execute() {
    }
}

private final class EqualityConstraint : BinaryConstraint {
    this(Variable var1, Variable var2, Sym* strength, Planner* planner) {
        super(var1, var2, strength, planner);
        addConstraint(planner);
    }

    override void execute() {
        if (direction == Direction.forward)
            v2.setValue(v1.getValue());
        else
            v1.setValue(v2.getValue());
    }
}

private struct Plan {
    Vector!AbstractConstraint vector;
    alias vector this;

    this(size_t size) {
        vector = Vector!AbstractConstraint(size);
    }

    void execute() {
        forEach((c) { c.execute(); });
    }
}

private final class ScaleConstraint : BinaryConstraint {
    private Variable scale;
    private Variable offset;

    this(Variable src, Variable scale, Variable offset, Variable dest,
         Sym* strength, Planner* planner) {
        super(src, dest, strength, planner);
        this.scale = scale;
        this.offset = offset;
        addConstraint(planner);
    }

    override void addToGraph() {
        v1.addConstraint(this);
        v2.addConstraint(this);
        scale.addConstraint(this);
        offset.addConstraint(this);
        direction = Direction.none;
    }

    override void removeFromGraph() {
        if (v1 !is null)
            v1.removeConstraint(this);
        if (v2 !is null)
            v2.removeConstraint(this);
        if (scale !is null)
            scale.removeConstraint(this);
        if (offset !is null)
            offset.removeConstraint(this);
        direction = Direction.none;
    }

    override void execute() {
        if (direction == Direction.forward)
            v2.setValue(v1.getValue() * scale.getValue() + offset.getValue());
        else
            v1.setValue((v2.getValue() - offset.getValue()) / scale.getValue());
    }

    override void inputsDo(scope void delegate(Variable) fn) {
        if (direction == Direction.forward) {
            fn(v1);
            fn(scale);
            fn(offset);
        } else {
            fn(v2);
            fn(scale);
            fn(offset);
        }
    }

    override void recalculate() {
        Variable in_;
        Variable out_;
        if (direction == Direction.forward) {
            in_ = v1;
            out_ = v2;
        } else {
            out_ = v1;
            in_ = v2;
        }

        out_.setWalkStrength(strength.weakest(in_.getWalkStrength()));
        out_.setStay(in_.getStay() && scale.getStay() && offset.getStay());
        if (out_.getStay())
            execute();
    }
}

private final class StayConstraint : UnaryConstraint {
    this(Variable v, Sym* strength, Planner* planner) {
        super(v, strength, planner);
        addConstraint(planner);
    }

    override void execute() {
    }
}

private struct Planner {
    private int currentMark = 1;

    void incrementalAdd(AbstractConstraint c) {
        const mark = newMark();
        AbstractConstraint overridden = c.satisfy(mark, &this);
        while (overridden !is null)
            overridden = overridden.satisfy(mark, &this);
    }

    void incrementalRemove(AbstractConstraint c) {
        Variable out_ = c.getOutput();
        c.markUnsatisfied();
        c.removeFromGraph();
        Vector!AbstractConstraint* unsatisfied = removePropagateFrom(out_);
        unsatisfied.forEach((u) { incrementalAdd(u); });
        version (ManualMemory) dispose(unsatisfied);
    }

    Plan* extractPlanFromConstraints(Vector!AbstractConstraint* constraints) {
        Vector!AbstractConstraint sources;

        constraints.forEach((c) {
            if (c.isInput() && c.isSatisfied())
                sources.append(c);
        });

        return makePlan(&sources);
    }

    Plan* makePlan(Vector!AbstractConstraint* sources) {
        const mark = newMark();
        version (ManualMemory)
            auto plan = makePtr!Plan(15);
        else
            auto plan = new Plan(15);
        Vector!AbstractConstraint* todo = sources;

        while (!todo.isEmpty()) {
            AbstractConstraint c = todo.removeFirst();

            if (c.getOutput().getMark() != mark && c.inputsKnown(mark)) {
                plan.append(c);
                c.getOutput().setMark(mark);
                addConstraintsConsumingTo(c.getOutput(), todo);
            }
        }
        return plan;
    }

    void addConstraintsConsumingTo(Variable v, Vector!AbstractConstraint* coll) {
        AbstractConstraint determiningC = v.getDeterminedBy();
        v.getConstraints().forEach((c) {
            if (c !is determiningC && c.isSatisfied())
                coll.append(c);
        });
    }

    bool addPropagate(AbstractConstraint c, int mark) {
        auto todo = Vector!AbstractConstraint.with_(c);
        version (ManualMemory) scope(exit) dispose(todo);

        while (!todo.isEmpty()) {
            AbstractConstraint d = todo.removeFirst();

            if (d.getOutput().getMark() == mark) {
                incrementalRemove(c);
                return false;
            }
            d.recalculate();
            addConstraintsConsumingTo(d.getOutput(), todo);
        }
        return true;
    }

    void change(Variable var, int newValue) {
        version (ManualMemory)
            auto editC = make!EditConstraint(var, &Strength.preferred, &this);
        else
            auto editC = new EditConstraint(var, &Strength.preferred, &this);

        auto editV = Vector!AbstractConstraint.with_(editC);
        Plan* plan = extractPlanFromConstraints(editV);
        foreach (i; 0 .. 10) {
            var.setValue(newValue);
            plan.execute();
        }
        editC.destroyConstraint(&this);
        version (ManualMemory) {
            dispose(plan);
            dispose(editV);
        }
    }

    void constraintsConsuming(Variable v, scope void delegate(AbstractConstraint) fn) {
        AbstractConstraint determiningC = v.getDeterminedBy();
        v.getConstraints().forEach((c) {
            if (c !is determiningC && c.isSatisfied())
                fn(c);
        });
    }

    int newMark() {
        currentMark += 1;
        return currentMark;
    }

    Vector!AbstractConstraint* removePropagateFrom(Variable out_) {
        version (ManualMemory)
            auto unsatisfied = makePtr!(Vector!AbstractConstraint);
        else
            auto unsatisfied = new Vector!AbstractConstraint;

        out_.setDeterminedBy(null);
        out_.setWalkStrength(Strength.absoluteWeakest());
        out_.setStay(true);

        auto todo = Vector!Variable.with_(out_);

        while (!todo.isEmpty()) {
            Variable v = todo.removeFirst();

            v.getConstraints().forEach((c) {
                if (!c.isSatisfied())
                    unsatisfied.append(c);
            });

            constraintsConsuming(v, (c) {
                c.recalculate();
                todo.append(c.getOutput());
            });
        }
        version (ManualMemory) dispose(todo);

        unsatisfied.sort((c1, c2) => c1.getStrength().stronger(c2.getStrength()) ? -1 : 1);
        return unsatisfied;
    }

    static void chainTest(int n) {
        Strength.initializeConstants();
        Planner planner;
        version (ManualMemory)
            auto vars = makeArray!Variable(n + 1);
        else
            auto vars = new Variable[n + 1];
        foreach (ref v; vars)
            version (ManualMemory)
                v = make!Variable;
            else
                v = new Variable;

        foreach (i; 0 .. n) {
            Variable v1 = vars[i];
            Variable v2 = vars[i + 1];
            version (ManualMemory)
                make!EqualityConstraint(v1, v2, &Strength.required_, &planner);
            else
                new EqualityConstraint(v1, v2, &Strength.required_, &planner);
        }

        version (ManualMemory)
            make!StayConstraint(vars[n], &Strength.strongDefault, &planner);
        else
            new StayConstraint(vars[n], &Strength.strongDefault, &planner);
        version (ManualMemory)
            auto editC = make!EditConstraint(vars[0], &Strength.preferred, &planner);
        else
            auto editC = new EditConstraint(vars[0], &Strength.preferred, &planner);

        auto editV = Vector!AbstractConstraint.with_(editC);
        Plan* plan = planner.extractPlanFromConstraints(editV);
        version (ManualMemory) dispose(editV);
        foreach (i; 0 .. 100) {
            vars[0].setValue(i);
            plan.execute();
            if (vars[n].getValue() != i)
                throw new SomError("Chain test failed!");
        }
        editC.destroyConstraint(&planner);
        version (ManualMemory) {
            dispose(plan);
            disposeArray(vars);
        }
        ObjectTracker.releaseAll();
    }

    static void projectionTest(int n) {
        Planner planner;
        Vector!Variable dests;

        Variable scale = Variable.value_(10);
        Variable offset = Variable.value_(1000);

        Variable src;
        Variable dst;

        foreach (i; 1 .. n + 1) {
            src = Variable.value_(i);
            dst = Variable.value_(i);
            dests.append(dst);
            version (ManualMemory)
                make!StayConstraint(src, &Strength.default_, &planner);
            else
                new StayConstraint(src, &Strength.default_, &planner);
            version (ManualMemory)
                make!ScaleConstraint(src, scale, offset, dst, &Strength.required_, &planner);
            else
                new ScaleConstraint(src, scale, offset, dst, &Strength.required_, &planner);
        }

        planner.change(src, 17);
        if (dst.getValue() != 1170)
            throw new SomError("Projection test 1 failed!");

        planner.change(dst, 1050);
        if (src.getValue() != 5)
            throw new SomError("Projection test 2 failed!");

        planner.change(scale, 5);

        foreach (i; 0 .. n - 1) {
            if (dests.at(i).getValue() != (i + 1) * 5 + 1000)
                throw new SomError("Projection test 3 failed!");
        }

        planner.change(offset, 2000);

        foreach (i; 0 .. n - 1) {
            if (dests.at(i).getValue() != (i + 1) * 5 + 2000)
                throw new SomError("Projection test 4 failed!");
        }
        ObjectTracker.releaseAll();
        Strength.releaseConstants();
    }
}

final class DeltaBlue : Runnable {
    bool innerBenchmarkLoop(int innerIterations) {
        Planner.chainTest(innerIterations);
        Planner.projectionTest(innerIterations);
        return true;
    }
}
