module havlak;

import benchmark;
import memory;
import som.identity_dictionary;
import som.identity_set;
import som.set;
import som.vector;
import std.stdio : writeln;

private struct BasicBlock {
    private Vector!(BasicBlock*) inEdges;
    private Vector!(BasicBlock*) outEdges;
    private uint name;

    this(int name) {
        inEdges = Vector!(BasicBlock*)(2);
        outEdges = Vector!(BasicBlock*)(2);
        this.name = name;
    }

    ref Vector!(BasicBlock*) getInEdges() {
        return inEdges;
    }

    ref Vector!(BasicBlock*) getOutEdges() {
        return outEdges;
    }

    int getNumPred() const {
        return cast(int) inEdges.size();
    }

    void addOutEdge(BasicBlock* to) {
        outEdges.append(to);
    }

    void addInEdge(BasicBlock* from) {
        inEdges.append(from);
    }

    uint customHash() const {
        return name;
    }

    bool equal(BasicBlock* other) const {
        return name == other.name;
    }
}

private struct ControlFlowGraph {
    private Vector!(BasicBlock*) basicBlockMap;
    private BasicBlock* startNode;
    private Vector!(BasicBlockEdge*) edgeList;

    @disable this(this);

    version (ManualMemory) ~this() {
        basicBlockMap.destroyValues();
        edgeList.destroyValues();
    }

    BasicBlock* createNode(int name) {
        BasicBlock* node;
        if (basicBlockMap.at(name) !is null) {
            node = basicBlockMap.at(name);
        } else {
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                node = makePtr!BasicBlock(name);
            else
                node = new BasicBlock(name);
            basicBlockMap.atPut(name, node);
        }

        if (getNumNodes() == 1)
            startNode = node;
        return node;
    }

    void addEdge(BasicBlockEdge* edge) {
        edgeList.append(edge);
    }

    int getNumNodes() const {
        return cast(int) basicBlockMap.size();
    }

    BasicBlock* getStartBasicBlock() {
        return startNode;
    }

    ref Vector!(BasicBlock*) getBasicBlocks() {
        return basicBlockMap;
    }
}

private struct BasicBlockEdge {
    private BasicBlock* from;
    private BasicBlock* to;

    this(ref ControlFlowGraph cfg, int fromName, int toName) {
        from = cfg.createNode(fromName);
        to = cfg.createNode(toName);

        from.addOutEdge(to);
        to.addInEdge(from);

        cfg.addEdge(&this);
    }
}

private struct SimpleLoop {
    private IdentitySet!(BasicBlock*) basicBlocks;
    private IdentitySet!(SimpleLoop*) children;
    private SimpleLoop* parent;
    private BasicBlock* header;

    private bool isReducible;
    private bool isRoot_;
    private int nestingLevel;
    private int counter;
    private int depthLevel;

    this(BasicBlock* bb, bool isReducible) {
        basicBlocks = IdentitySet!(BasicBlock*)(initialSize);
        children = IdentitySet!(SimpleLoop*)(initialSize);
        header = bb;
        this.isReducible = isReducible;

        if (bb !is null)
            basicBlocks.add(bb);
    }

    private void addChildLoop(SimpleLoop* loop) {
        children.add(loop);
    }

    void addNode(BasicBlock* bb) {
        basicBlocks.add(bb);
    }

    bool equal(SimpleLoop* other) const {
        return &this is other;
    }

    ref IdentitySet!(SimpleLoop*) getChildren() {
        return children;
    }

    SimpleLoop* getParent() {
        return parent;
    }

    int getNestingLevel() const {
        return nestingLevel;
    }

    bool isRoot() const {
        return isRoot_;
    }

    void setParent(SimpleLoop* parent) {
        this.parent = parent;
        this.parent.addChildLoop(&this);
    }

    void setIsRoot() {
        isRoot_ = true;
    }

    void setCounter(int value) {
        counter = value;
    }

    void setNestingLevel(int level) {
        nestingLevel = level;
        if (level == 0)
            setIsRoot();
    }

    void setDepthLevel(int level) {
        depthLevel = level;
    }
}

private struct LoopStructureGraph {
    private SimpleLoop* root;
    private Vector!(SimpleLoop*) loops;
    private int loopCounter;

    @disable this(this);

    static LoopStructureGraph create() {
        LoopStructureGraph graph;
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            graph.root = makePtr!SimpleLoop(null, true);
        else
            graph.root = new SimpleLoop(null, true);
        graph.root.setNestingLevel(0);
        graph.root.setCounter(graph.loopCounter);
        graph.loopCounter += 1;
        graph.loops.append(graph.root);
        return graph;
    }

    version (ManualMemory) ~this() {
        loops.destroyValues();
    }

    SimpleLoop* createNewLoop(BasicBlock* bb, bool isReducible) {
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            auto loop = makePtr!SimpleLoop(bb, isReducible);
        else
            auto loop = new SimpleLoop(bb, isReducible);
        loop.setCounter(loopCounter);
        loopCounter += 1;
        loops.append(loop);
        return loop;
    }

    void calculateNestingLevel() {
        // link up all 1st level loops to artificial root node.
        loops.forEach((liter) {
            if (!liter.isRoot()) {
                if (liter.getParent() is null)
                    liter.setParent(root);
            }
        });

        // recursively traverse the tree and assign levels.
        calculateNestingLevelRec(root, 0);
    }

    void calculateNestingLevelRec(SimpleLoop* loop, int depth) {
        loop.setDepthLevel(depth);
        loop.getChildren().forEach((liter) {
            calculateNestingLevelRec(liter, depth + 1);

            const level = 1 + liter.getNestingLevel();
            if (level > loop.getNestingLevel())
                loop.setNestingLevel(level);
        });
    }

    int getNumLoops() const {
        return cast(int) loops.size();
    }
}

private struct UnionFindNode {
    private UnionFindNode* parent;
    private BasicBlock* bb;
    private SimpleLoop* loop;
    private int dfsNumber;

    void initNode(BasicBlock* bb, int dfsNumber) {
        parent = &this;
        this.bb = bb;
        this.dfsNumber = dfsNumber;
        loop = null;
    }

    UnionFindNode* findSet() {
        Vector!(UnionFindNode*) nodeList;

        UnionFindNode* node = &this;
        while (node !is node.parent) {
            if (node.parent !is node.parent.parent)
                nodeList.append(node);
            node = node.parent;
        }

        // Path Compression, all nodes' parents point to the 1st level parent.
        nodeList.forEach((iter) { iter.unionSet(parent); });
        return node;
    }

    void unionSet(UnionFindNode* basicBlock) {
        parent = basicBlock;
    }

    BasicBlock* getBb() {
        return bb;
    }

    SimpleLoop* getLoop() {
        return loop;
    }

    int getDfsNumber() const {
        return dfsNumber;
    }

    void setLoop(SimpleLoop* loop) {
        this.loop = loop;
    }
}

private struct HavlakLoopFinder {
    private enum BasicBlockClass {
        top,
        nonHeader,
        reducible,
        self,
        irreducible,
        dead,
        last,
    }

    private ControlFlowGraph* cfg;
    private LoopStructureGraph* lsg;

    private enum unvisited = int.max;
    private enum maxNonBackPreds = 32 * 1024;

    private Vector!(Set!int*) nonBackPreds;
    private Vector!(Vector!int*) backPreds;
    private IdentityDictionary!(BasicBlock*, int) number;
    private int maxSize;
    private int[] header;
    private BasicBlockClass[] type;
    private int[] last;
    private UnionFindNode*[] nodes;

    @disable this(this);

    this(ControlFlowGraph* cfg, LoopStructureGraph* lsg) {
        this.cfg = cfg;
        this.lsg = lsg;
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            number = make!(typeof(number));
        else
            number = new typeof(number);
    }

    version (ManualMemory) ~this() {
        nonBackPreds.destroyValues();
        backPreds.destroyValues();
        // GC build: nothing to free; the empty call would
        // still cost a guest call.
        version (ManualMemory) {
            dispose(number);
            disposeArray(header);
            disposeArray(type);
            disposeArray(last);
        }
        foreach (ref node; nodes)
            // GC build: nothing to free; the empty call would
            // still cost a guest call.
            version (ManualMemory) dispose(node);
        // GC build: nothing to free; the empty call would
        // still cost a guest call.
        version (ManualMemory) disposeArray(nodes);
    }

    void findLoops() {
        if (cfg.getStartBasicBlock() is null)
            return;

        const size = cfg.getNumNodes();

        nonBackPreds.destroyValues();
        backPreds.destroyValues();
        nonBackPreds.removeAll();
        backPreds.removeAll();
        number.removeAll();

        if (size > maxSize) {
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                header = makeArray!int(size);
            else
                header = new int[size];
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                type = makeArray!BasicBlockClass(size);
            else
                type = new BasicBlockClass[size];
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                last = makeArray!int(size);
            else
                last = new int[size];
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                nodes = makeArray!(UnionFindNode*)(size);
            else
                nodes = new UnionFindNode*[size];
            maxSize = size;
        }

        foreach (i; 0 .. size) {
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                nonBackPreds.append(makePtr!(Set!int)(initialSize));
            else
                nonBackPreds.append(new Set!int(initialSize));
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                backPreds.append(makePtr!(Vector!int)());
            else
                backPreds.append(new Vector!int());
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                nodes[i] = makePtr!UnionFindNode;
            else
                nodes[i] = new UnionFindNode;
        }

        initAllNodes();
        identifyEdges(size);

        // Start node is root of all other loops.
        header[0] = 0;

        for (int w = size - 1; w >= 0; w -= 1) {
            // this is 'P' in Havlak's paper
            Vector!(UnionFindNode*) nodePool;

            BasicBlock* nodeW = nodes[w].getBb();
            if (nodeW !is null) {
                stepD(w, nodePool);

                // Copy nodePool to workList.
                Vector!(UnionFindNode*) workList;
                nodePool.forEach((niter) { workList.append(niter); });

                if (nodePool.size() != 0)
                    type[w] = BasicBlockClass.reducible;

                // work the list...
                while (!workList.isEmpty()) {
                    UnionFindNode* x = workList.removeFirst();

                    // Step e:
                    //
                    // Step e represents the main difference from Tarjan's method.
                    // Chasing upwards from the sources of a node w's backedges. If
                    // there is a node y' that is not a descendant of w, w is marked
                    // the header of an irreducible loop, there is another entry
                    // into this loop that avoids w.

                    // The algorithm has degenerated. Break and
                    // return in this case.
                    const nonBackSize = cast(int) nonBackPreds.at(x.getDfsNumber()).size();
                    if (nonBackSize > maxNonBackPreds)
                        return;
                    stepEProcessNonBackPreds(w, nodePool, workList, x);
                }

                // Collapse/Unionize nodes in a SCC to a single node
                // For every SCC found, create a loop descriptor and link it in.
                if (nodePool.size() > 0 || type[w] == BasicBlockClass.self) {
                    SimpleLoop* loop = lsg.createNewLoop(nodeW, type[w] != BasicBlockClass.irreducible);
                    setLoopAttributes(w, nodePool, loop);
                }
            }
        }
    }

    private bool isAncestor(int w, int v) {
        return w <= v && v <= last[w];
    }

    private int doDFS(BasicBlock* currentNode, int current) {
        nodes[current].initNode(currentNode, current);
        number.atPut(currentNode, current);

        int lastId = current;
        auto outerBlocks = &currentNode.getOutEdges();

        foreach (i; 0 .. outerBlocks.size()) {
            BasicBlock* target = outerBlocks.at(i);
            if (number.at(target) == unvisited)
                lastId = doDFS(target, lastId + 1);
        }

        last[current] = lastId;
        return lastId;
    }

    private void initAllNodes() {
        // Step a:
        //   - initialize all nodes as unvisited.
        //   - depth-first traversal and numbering.
        //   - unreached BB's are marked as dead.
        cfg.getBasicBlocks().forEach((bb) { number.atPut(bb, unvisited); });
        doDFS(cfg.getStartBasicBlock(), 0);
    }

    private void identifyEdges(int size) {
        // Step b:
        //   - iterate over all nodes.
        //
        //   A backedge comes from a descendant in the DFS tree, and non-backedges
        //   from non-descendants (following Tarjan).
        //
        //   - check incoming edges 'v' and add them to either
        //     - the list of backedges (backPreds) or
        //     - the list of non-backedges (nonBackPreds)
        foreach (w; 0 .. size) {
            header[w] = 0;
            type[w] = BasicBlockClass.nonHeader;

            BasicBlock* nodeW = nodes[w].getBb();
            if (nodeW is null)
                type[w] = BasicBlockClass.dead;
            else
                processEdges(nodeW, w);
        }
    }

    private void processEdges(BasicBlock* nodeW, int w) {
        if (nodeW.getNumPred() > 0) {
            nodeW.getInEdges().forEach((nodeV) {
                const v = number.at(nodeV);
                if (v != unvisited) {
                    if (isAncestor(w, v))
                        backPreds.at(w).append(v);
                    else
                        nonBackPreds.at(w).add(v);
                }
            });
        }
    }

    private void stepEProcessNonBackPreds(int w, ref Vector!(UnionFindNode*) nodePool,
                                          ref Vector!(UnionFindNode*) workList, UnionFindNode* x) {
        nonBackPreds.at(x.getDfsNumber()).forEach((iter) {
            UnionFindNode* y = nodes[iter];
            UnionFindNode* ydash = y.findSet();

            if (!isAncestor(w, ydash.getDfsNumber())) {
                type[w] = BasicBlockClass.irreducible;
                nonBackPreds.at(w).add(ydash.getDfsNumber());
            } else {
                if (ydash.getDfsNumber() != w) {
                    if (!nodePool.hasSome((e) => e is ydash)) {
                        workList.append(ydash);
                        nodePool.append(ydash);
                    }
                }
            }
        });
    }

    private void setLoopAttributes(int w, ref Vector!(UnionFindNode*) nodePool, SimpleLoop* loop) {
        // At this point, one can set attributes to the loop, such as:
        //
        // the bottom node:
        //    iterate over all the primitive nodes, find the one that
        //    does not have an edge to the loop header.
        //
        // the number of exits:
        //    like the number of back edges, but now exits.
        nodes[w].setLoop(loop);

        nodePool.forEach((node) {
            // Add nodes to loop descriptor.
            header[node.getDfsNumber()] = w;
            node.unionSet(nodes[w]);

            // Nested loops are not added, but linked together.
            if (node.getLoop() !is null)
                node.getLoop().setParent(loop);
            else
                loop.addNode(node.getBb());
        });
    }

    private void stepD(int w, ref Vector!(UnionFindNode*) nodePool) {
        backPreds.at(w).forEach((v) {
            if (v != w)
                nodePool.append(nodes[v].findSet());
            else
                type[w] = BasicBlockClass.self;
        });
    }
}

private struct LoopTesterApp {
    private ControlFlowGraph cfg;
    private LoopStructureGraph lsg;

    @disable this(this);

    static LoopTesterApp create() {
        LoopTesterApp app;
        app.lsg = LoopStructureGraph.create();
        app.cfg.createNode(0);
        return app;
    }

    private int buildDiamond(int start) {
        const bb0 = start;
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, bb0, bb0 + 1);
        else
            new BasicBlockEdge(cfg, bb0, bb0 + 1);
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, bb0, bb0 + 2);
        else
            new BasicBlockEdge(cfg, bb0, bb0 + 2);
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, bb0 + 1, bb0 + 3);
        else
            new BasicBlockEdge(cfg, bb0 + 1, bb0 + 3);
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, bb0 + 2, bb0 + 3);
        else
            new BasicBlockEdge(cfg, bb0 + 2, bb0 + 3);
        return bb0 + 3;
    }

    private void buildConnect(int start, int end) {
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, start, end);
        else
            new BasicBlockEdge(cfg, start, end);
    }

    private int buildStraight(int start, int n) {
        foreach (i; 0 .. n)
            buildConnect(start + i, start + i + 1);
        return start + n;
    }

    private int buildBaseLoop(int from) {
        const header = buildStraight(from, 1);
        const diamond1 = buildDiamond(header);
        const d11 = buildStraight(diamond1, 1);
        const diamond2 = buildDiamond(d11);
        int footer = buildStraight(diamond2, 1);
        buildConnect(diamond2, d11);
        buildConnect(diamond1, header);

        buildConnect(footer, from);
        footer = buildStraight(footer, 1);
        return footer;
    }

    private void constructSimpleCFG() {
        cfg.createNode(0);
        buildBaseLoop(0);
        cfg.createNode(1);
        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            makePtr!BasicBlockEdge(cfg, 0, 2);
        else
            new BasicBlockEdge(cfg, 0, 2);
    }

    int[2] main(int numDummyLoops, int findLoopIterations, int parLoops,
                int pparLoops, int ppparLoops) {
        constructSimpleCFG();
        addDummyLoops(numDummyLoops);
        constructCFG(parLoops, pparLoops, ppparLoops);
        findLoops(lsg);

        foreach (i; 0 .. findLoopIterations) {
            auto loopStructure = LoopStructureGraph.create();
            findLoops(loopStructure);
        }

        lsg.calculateNestingLevel();
        return [lsg.getNumLoops(), cfg.getNumNodes()];
    }

    private void constructCFG(int parLoops, int pparLoops, int ppparLoops) {
        int n = 2;

        foreach (parlooptrees; 0 .. parLoops) {
            cfg.createNode(n + 1);
            buildConnect(2, n + 1);
            n += 1;

            foreach (i; 0 .. pparLoops) {
                const top = n;
                n = buildStraight(n, 1);
                foreach (j; 0 .. ppparLoops)
                    n = buildBaseLoop(n);
                const bottom = buildStraight(n, 1);
                buildConnect(n, top);
                n = bottom;
            }
            buildConnect(n, 1);
        }
    }

    private void addDummyLoops(int numDummyLoops) {
        foreach (dummyloop; 0 .. numDummyLoops)
            findLoops(lsg);
    }

    private void findLoops(ref LoopStructureGraph loopStructure) {
        auto finder = HavlakLoopFinder(&cfg, &loopStructure);
        finder.findLoops();
    }
}

final class Havlak : Runnable {
    bool innerBenchmarkLoop(int innerIterations) {
        return verifyResult(run(innerIterations), innerIterations);
    }

    int[2] run(int innerIterations) {
        auto app = LoopTesterApp.create();
        return app.main(innerIterations, 50, 10 /* was 100 */, 10, 5);
    }

    bool verifyResult(int[2] r, int innerIterations) {
        if (innerIterations == 15_000)
            return r[0] == 46_602 && r[1] == 5213;
        if (innerIterations == 1500)
            return r[0] == 6102 && r[1] == 5213;
        if (innerIterations == 150)
            return r[0] == 2052 && r[1] == 5213;
        if (innerIterations == 15)
            return r[0] == 1647 && r[1] == 5213;
        if (innerIterations == 1)
            return r[0] == 1605 && r[1] == 5213;

        writeln("No verification result for ", innerIterations, " found");
        writeln("Result is: ", r[0], ", ", r[1]);
        return false;
    }
}
