module cd;

import benchmark;
import core.math : cos, sin, sqrt;
import memory;
import som.vector;
import std.stdio : writeln;

private struct Optional(T) {
    bool hasValue;
    T value;

    this(T value) {
        hasValue = true;
        this.value = value;
    }
}

private struct Vector2D {
    double x;
    double y;

    private static int compareNumbers(double a, double b) {
        if (a == b)
            return 0;
        if (a < b)
            return -1;
        if (a > b)
            return 1;

        // We say that NaN is smaller than non-NaN.
        if (a == a)
            return 1;
        return -1;
    }

    Vector2D plus(Vector2D other) const {
        return Vector2D(x + other.x, y + other.y);
    }

    Vector2D minus(Vector2D other) const {
        return Vector2D(x - other.x, y - other.y);
    }

    int compareTo(Vector2D other) const {
        const result = compareNumbers(x, other.x);
        if (result != 0)
            return result;
        return compareNumbers(y, other.y);
    }
}

private struct Vector3D {
    double x;
    double y;
    double z;

    Vector3D plus(Vector3D other) const {
        return Vector3D(x + other.x, y + other.y, z + other.z);
    }

    Vector3D minus(Vector3D other) const {
        return Vector3D(x - other.x, y - other.y, z - other.z);
    }

    double dot(Vector3D other) const {
        return x * other.x + y * other.y + z * other.z;
    }

    double squaredMagnitude() const {
        return dot(this);
    }

    double magnitude() const {
        return sqrt(squaredMagnitude());
    }

    Vector3D times(double amount) const {
        return Vector3D(x * amount, y * amount, z * amount);
    }
}

private struct RedBlackTree(K, V) {
    private enum Color {
        red,
        black,
    }

    private static struct Node {
        K key;
        V value;
        Node* left;
        Node* right;
        Node* parent;
        Color color = Color.red;

        this(K key, V value) {
            this.key = key;
            this.value = value;
        }

        version (ManualMemory) ~this() {
            dispose(left);
            dispose(right);
        }

        Node* successor() {
            Node* x = &this;
            if (x.right !is null)
                return treeMinimum(x.right);

            Node* y = x.parent;
            while (y !is null && x is y.right) {
                x = y;
                y = y.parent;
            }
            return y;
        }
    }

    private struct InsertResult {
        bool isNewEntry;
        Node* newNode;
        V oldValue;
    }

    struct Entry {
        K key;
        V value;
    }

    private Node* root;

    @disable this(this);

    version (ManualMemory) ~this() {
        dispose(root);
    }

    private static Node* treeMinimum(Node* x) {
        Node* current = x;
        while (current.left !is null)
            current = current.left;
        return current;
    }

    Optional!V put(K key, V value) {
        InsertResult insertionResult = treeInsert(key, value);
        if (!insertionResult.isNewEntry)
            return Optional!V(insertionResult.oldValue);
        Node* x = insertionResult.newNode;

        while (x !is root && x.parent.color == Color.red) {
            if (x.parent is x.parent.parent.left) {
                Node* y = x.parent.parent.right;
                if (y !is null && y.color == Color.red) {
                    // Case 1
                    x.parent.color = Color.black;
                    y.color = Color.black;
                    x.parent.parent.color = Color.red;
                    x = x.parent.parent;
                } else {
                    if (x is x.parent.right) {
                        // Case 2
                        x = x.parent;
                        leftRotate(x);
                    }
                    // Case 3
                    x.parent.color = Color.black;
                    x.parent.parent.color = Color.red;
                    rightRotate(x.parent.parent);
                }
            } else {
                // Same as "then" clause with "right" and "left" exchanged.
                Node* y = x.parent.parent.left;
                if (y !is null && y.color == Color.red) {
                    // Case 1
                    x.parent.color = Color.black;
                    y.color = Color.black;
                    x.parent.parent.color = Color.red;
                    x = x.parent.parent;
                } else {
                    if (x is x.parent.left) {
                        // Case 2
                        x = x.parent;
                        rightRotate(x);
                    }
                    // Case 3
                    x.parent.color = Color.black;
                    x.parent.parent.color = Color.red;
                    leftRotate(x.parent.parent);
                }
            }
        }

        root.color = Color.black;
        return Optional!V();
    }

    Optional!V remove(K key) {
        Node* z = findNode(key);
        if (z is null)
            return Optional!V();

        // Y is the node to be unlinked from the tree.
        Node* y;
        if (z.left is null || z.right is null)
            y = z;
        else
            y = z.successor();

        // Y is guaranteed to be non-null at this point.
        Node* x;
        if (y.left !is null)
            x = y.left;
        else
            x = y.right;

        // X is the child of y which might potentially replace y in the tree. X
        // might be null at this point.
        Node* xParent;
        if (x !is null) {
            x.parent = y.parent;
            xParent = x.parent;
        } else {
            xParent = y.parent;
        }
        if (y.parent is null) {
            root = x;
        } else {
            if (y is y.parent.left)
                y.parent.left = x;
            else
                y.parent.right = x;
        }

        if (y !is z) {
            if (y.color == Color.black)
                removeFixup(x, xParent);

            y.parent = z.parent;
            y.color = z.color;
            y.left = z.left;
            y.right = z.right;

            if (z.left !is null)
                z.left.parent = y;
            if (z.right !is null)
                z.right.parent = y;
            if (z.parent !is null) {
                if (z.parent.left is z)
                    z.parent.left = y;
                else
                    z.parent.right = y;
            } else {
                root = y;
            }
        } else if (y.color == Color.black) {
            removeFixup(x, xParent);
        }
        auto removed = Optional!V(z.value);
        z.left = null;
        z.right = null;
        dispose(z);
        return removed;
    }

    V* get(K key) {
        Node* node = findNode(key);
        if (node is null)
            return null;
        return &node.value;
    }

    void forEach(scope void delegate(Entry) fn) {
        if (root is null)
            return;

        Node* current = treeMinimum(root);
        while (current !is null) {
            fn(Entry(current.key, current.value));
            current = current.successor();
        }
    }

    private Node* findNode(K key) {
        Node* current = root;
        while (current !is null) {
            const comparisonResult = key.compareTo(current.key);
            if (comparisonResult == 0)
                return current;
            if (comparisonResult < 0)
                current = current.left;
            else
                current = current.right;
        }
        return null;
    }

    private InsertResult treeInsert(K key, V value) {
        Node* y;
        Node* x = root;
        while (x !is null) {
            y = x;
            const comparisonResult = key.compareTo(x.key);
            if (comparisonResult < 0) {
                x = x.left;
            } else if (comparisonResult > 0) {
                x = x.right;
            } else {
                V oldValue = x.value;
                x.value = value;
                return InsertResult(false, null, oldValue);
            }
        }

        Node* z = makePtr!Node(key, value);
        z.parent = y;
        if (y is null) {
            root = z;
        } else {
            if (key.compareTo(y.key) < 0)
                y.left = z;
            else
                y.right = z;
        }
        return InsertResult(true, z, V.init);
    }

    private Node* leftRotate(Node* x) {
        Node* y = x.right;

        // Turn y's left subtree into x's right subtree.
        x.right = y.left;
        if (y.left !is null)
            y.left.parent = x;

        // Link x's parent to y
        y.parent = x.parent;
        if (x.parent is null) {
            root = y;
        } else {
            if (x is x.parent.left)
                x.parent.left = y;
            else
                x.parent.right = y;
        }

        // Put x on y's left.
        y.left = x;
        x.parent = y;

        return y;
    }

    private Node* rightRotate(Node* y) {
        Node* x = y.left;

        // Turn x's right subtree into y's left subtree.
        y.left = x.right;
        if (x.right !is null)
            x.right.parent = y;

        // Link y's parent to x;
        x.parent = y.parent;
        if (y.parent is null) {
            root = x;
        } else {
            if (y is y.parent.left)
                y.parent.left = x;
            else
                y.parent.right = x;
        }

        x.right = y;
        y.parent = x;

        return x;
    }

    private void removeFixup(Node* x, Node* xParent) {
        while (x !is root && (x is null || x.color == Color.black)) {
            if (x is xParent.left) {
                // Note: the text points out that w cannot be null. The reason is not
                // obvious from simply looking at the code; it comes about from the
                // properties of the red-black tree.
                Node* w = xParent.right;
                if (w.color == Color.red) {
                    // Case 1
                    w.color = Color.black;
                    xParent.color = Color.red;
                    leftRotate(xParent);
                    w = xParent.right;
                }
                if ((w.left is null || w.left.color == Color.black) &&
                    (w.right is null || w.right.color == Color.black)) {
                    // Case 2
                    w.color = Color.red;
                    x = xParent;
                    xParent = x.parent;
                } else {
                    if (w.right is null || w.right.color == Color.black) {
                        // Case 3
                        w.left.color = Color.black;
                        w.color = Color.red;
                        rightRotate(w);
                        w = xParent.right;
                    }
                    // Case 4
                    w.color = xParent.color;
                    xParent.color = Color.black;
                    if (w.right !is null)
                        w.right.color = Color.black;
                    leftRotate(xParent);
                    x = root;
                    xParent = x.parent;
                }
            } else {
                // Same as "then" clause with "right" and "left" exchanged.
                Node* w = xParent.left;
                if (w.color == Color.red) {
                    // Case 1
                    w.color = Color.black;
                    xParent.color = Color.red;
                    rightRotate(xParent);
                    w = xParent.left;
                }
                if ((w.right is null || w.right.color == Color.black) &&
                    (w.left is null || w.left.color == Color.black)) {
                    // Case 2
                    w.color = Color.red;
                    x = xParent;
                    xParent = x.parent;
                } else {
                    if (w.left is null || w.left.color == Color.black) {
                        // Case 3
                        w.right.color = Color.black;
                        w.color = Color.red;
                        leftRotate(w);
                        w = xParent.left;
                    }
                    // Case 4
                    w.color = xParent.color;
                    xParent.color = Color.black;
                    if (w.left !is null)
                        w.left.color = Color.black;
                    rightRotate(xParent);
                    x = root;
                    xParent = x.parent;
                }
            }
        }
        if (x !is null)
            x.color = Color.black;
    }
}

private struct CallSign {
    int value;

    int compareTo(CallSign other) const {
        return (value == other.value) ? 0 : ((value < other.value) ? -1 : 1);
    }
}

private struct Collision {
    CallSign aircraftA;
    CallSign aircraftB;
    Vector3D position;
}

private enum minX = 0.0;
private enum minY = 0.0;
private enum maxX = 1000.0;
private enum maxY = 1000.0;
private enum minZ = 0.0;
private enum maxZ = 10.0;
private enum proximityRadius = 1.0;
private enum goodVoxelSize = proximityRadius * 2.0;

private struct Motion {
    CallSign callsign;
    Vector3D posOne;
    Vector3D posTwo;

    private Vector3D delta() const {
        return posTwo.minus(posOne);
    }

    Optional!Vector3D findIntersection(Motion other) const {
        const init1 = posOne;
        const init2 = other.posOne;
        const vec1 = delta();
        const vec2 = other.delta();
        const radius = proximityRadius;

        // this test is not geometrical 3-d intersection test, it takes the fact
        // that the aircraft move into account ; so it is more like a 4d test (it
        // assumes that both of the aircraft have a constant speed over the tested
        // interval)

        // we thus have two points, each of them moving on its line segment at
        // constant speed ; we are looking for times when the distance between these
        // two points is smaller than r

        // vec1 is vector of aircraft 1
        // vec2 is vector of aircraft 2

        // a = (V2 - V1)^T * (V2 - V1)
        const a = vec2.minus(vec1).squaredMagnitude();

        if (a != 0.0) {
            // we are first looking for instances of time when the planes are exactly
            // r from each other at least one plane is moving ; if the planes are
            // moving in parallel, they do not have constant speed

            // if the planes are moving in parallel, then
            //   if the faster starts behind the slower, we can have 2, 1, or 0
            //   solutions if the faster plane starts in front of the slower, we can
            //   have 0 or 1 solutions

            // if the planes are not moving in parallel, then

            // point P1 = I1 + vV1
            // point P2 = I2 + vV2
            //   - looking for v, such that dist(P1,P2) = || P1 - P2 || = r

            // it follows that || P1 - P2 || = sqrt( < P1-P2, P1-P2 > )
            //   0 = -r^2 + < P1 - P2, P1 - P2 >
            //  from properties of dot product
            //   0 = -r^2 + <I1-I2,I1-I2> + v * 2<I1-I2, V1-V2> + v^2 *<V1-V2,V1-V2>
            //   so we calculate a, b, c - and solve the quadratic equation
            //   0 = c + bv + av^2

            // b = 2 * <I1-I2, V1-V2>
            const b = 2.0 * init1.minus(init2).dot(vec1.minus(vec2));

            // c = -r^2 + (I2 - I1)^T * (I2 - I1)
            const c = -radius * radius + init2.minus(init1).squaredMagnitude();

            const discr = b * b - 4.0 * a * c;
            if (discr < 0.0)
                return Optional!Vector3D();

            const v1 = (-b - sqrt(discr)) / (2.0 * a);
            const v2 = (-b + sqrt(discr)) / (2.0 * a);

            if (v1 <= v2 && ((v1 <= 1.0 && 1.0 <= v2) || (v1 <= 0.0 && 0.0 <= v2) ||
                             (0.0 <= v1 && v2 <= 1.0))) {
                // Pick a good "time" at which to report the collision.
                double v;
                if (v1 <= 0.0) {
                    // The collision started before this frame. Report it at the start of
                    // the frame.
                    v = 0.0;
                } else {
                    // The collision started during this frame. Report it at that moment.
                    v = v1;
                }

                const result1 = init1.plus(vec1.times(v));
                const result2 = init2.plus(vec2.times(v));

                const result = result1.plus(result2).times(0.5);
                if (result.x >= minX && result.x <= maxX &&
                    result.y >= minY && result.y <= maxY &&
                    result.z >= minZ && result.z <= maxZ)
                    return Optional!Vector3D(result);
            }

            return Optional!Vector3D();
        }

        // the planes have the same speeds and are moving in parallel (or they are
        // not moving at all) they  thus have the same distance all the time ; we
        // calculate it from the initial point

        // dist = || i2 - i1 || = sqrt(  ( i2 - i1 )^T * ( i2 - i1 ) )
        const dist = init2.minus(init1).magnitude();
        if (dist <= radius)
            return Optional!Vector3D(init1.plus(init2).times(0.5));
        return Optional!Vector3D();
    }
}

private struct Aircraft {
    CallSign callsign;
    Vector3D position;
}

private struct CollisionDetector {
    private alias VoxelMap = RedBlackTree!(Vector2D, Vector!Motion*);

    private RedBlackTree!(CallSign, Vector3D) state;

    private static immutable horizontal = Vector2D(goodVoxelSize, 0.0);
    private static immutable vertical = Vector2D(0.0, goodVoxelSize);

    @disable this(this);

    Vector!Collision* handleNewFrame(ref Vector!Aircraft frame) {
        Vector!Motion motions;
        RedBlackTree!(CallSign, bool) seen;
        Vector!CallSign toRemove;

        frame.forEach((aircraft) {
            Optional!Vector3D oldPosition = state.put(aircraft.callsign, aircraft.position);
            const newPosition = aircraft.position;

            seen.put(aircraft.callsign, true);

            if (!oldPosition.hasValue) {
                // Treat newly introduced aircraft as if they were stationary.
                oldPosition = Optional!Vector3D(newPosition);
            }

            motions.append(Motion(aircraft.callsign, oldPosition.value, newPosition));
        });

        // Remove aircraft that are no longer present.
        state.forEach((e) {
            bool* wasSeen = seen.get(e.key);
            if (wasSeen is null || !*wasSeen)
                toRemove.append(e.key);
        });

        toRemove.forEach((e) { state.remove(e); });

        auto allReduced = reduceCollisionSet(motions);
        auto collisions = makePtr!(Vector!Collision);
        allReduced.forEach((reduced) {
            for (size_t i = 0; i < reduced.size(); i += 1) {
                const motion1 = reduced.at(i);
                for (size_t j = i + 1; j < reduced.size(); j += 1) {
                    const motion2 = reduced.at(j);
                    Optional!Vector3D collision = motion1.findIntersection(motion2);
                    if (collision.hasValue) {
                        collisions.append(Collision(motion1.callsign, motion2.callsign,
                                                    collision.value));
                    }
                }
            }
        });
        allReduced.destroyValues();
        dispose(allReduced);

        return collisions;
    }

    private static bool isInVoxel(Vector2D voxel, Motion motion) {
        if (voxel.x > maxX || voxel.x < minX || voxel.y > maxY || voxel.y < minY)
            return false;

        const init = motion.posOne;
        const fin = motion.posTwo;

        const v_s = goodVoxelSize;
        const r = proximityRadius / 2.0;

        const v_x = voxel.x;
        const x0 = init.x;
        const xv = fin.x - init.x;

        const v_y = voxel.y;
        const y0 = init.y;
        const yv = fin.y - init.y;

        double low_x = (v_x - r - x0) / xv;
        double high_x = (v_x + v_s + r - x0) / xv;

        if (xv < 0.0) {
            const tmp = low_x;
            low_x = high_x;
            high_x = tmp;
        }

        double low_y = (v_y - r - y0) / yv;
        double high_y = (v_y + v_s + r - y0) / yv;

        if (yv < 0.0) {
            const tmp = low_y;
            low_y = high_y;
            high_y = tmp;
        }

        return (
            ((xv == 0.0 && v_x <= x0 + r && x0 - r <= v_x + v_s) /* no motion in x */
             || (low_x <= 1.0 && 1.0 <= high_x) || (low_x <= 0.0 && 0.0 <= high_x) ||
             (0.0 <= low_x && high_x <= 1.0)) &&
            ((yv == 0.0 && v_y <= y0 + r && y0 - r <= v_y + v_s) /* no motion in y */
             || ((low_y <= 1.0 && 1.0 <= high_y) || (low_y <= 0.0 && 0.0 <= high_y) ||
                 (0.0 <= low_y && high_y <= 1.0))) &&
            (xv == 0.0 || yv == 0.0 || /* no motion in x or y or both */
             (low_y <= high_x && high_x <= high_y) ||
             (low_y <= low_x && low_x <= high_y) ||
             (low_x <= low_y && high_y <= high_x)));
    }

    private static void putIntoMap(ref VoxelMap voxelMap, Vector2D voxel, Motion motion) {
        Vector!Motion** array = voxelMap.get(voxel);
        if (array is null) {
            auto arr = makePtr!(Vector!Motion);
            arr.append(motion);
            voxelMap.put(voxel, arr);
        } else {
            (*array).append(motion);
        }
    }

    private void recurse(ref VoxelMap voxelMap, ref RedBlackTree!(Vector2D, bool) seen,
                         Vector2D nextVoxel, Motion motion) {
        if (!isInVoxel(nextVoxel, motion))
            return;

        const old = seen.put(nextVoxel, true);
        if (old.hasValue && old.value)
            return;

        putIntoMap(voxelMap, nextVoxel, motion);

        recurse(voxelMap, seen, nextVoxel.minus(horizontal), motion);
        recurse(voxelMap, seen, nextVoxel.plus(horizontal), motion);
        recurse(voxelMap, seen, nextVoxel.minus(vertical), motion);
        recurse(voxelMap, seen, nextVoxel.plus(vertical), motion);
        recurse(voxelMap, seen, nextVoxel.minus(horizontal).minus(vertical), motion);
        recurse(voxelMap, seen, nextVoxel.minus(horizontal).plus(vertical), motion);
        recurse(voxelMap, seen, nextVoxel.plus(horizontal).minus(vertical), motion);
        recurse(voxelMap, seen, nextVoxel.plus(horizontal).plus(vertical), motion);
    }

    private Vector!(Vector!Motion*)* reduceCollisionSet(ref Vector!Motion motions) {
        VoxelMap voxelMap;
        motions.forEach((motion) { drawMotionOnVoxelMap(voxelMap, motion); });

        auto result = makePtr!(Vector!(Vector!Motion*));
        voxelMap.forEach((e) {
            if (e.value.size() > 1)
                result.append(e.value);
            else
                dispose(e.value);
        });
        return result;
    }

    private Vector2D voxelHash(Vector3D position) {
        const xDiv = cast(int) (position.x / goodVoxelSize);
        const yDiv = cast(int) (position.y / goodVoxelSize);

        double x = goodVoxelSize * xDiv;
        double y = goodVoxelSize * yDiv;

        if (position.x < 0)
            x -= goodVoxelSize;
        if (position.y < 0)
            y -= goodVoxelSize;

        return Vector2D(x, y);
    }

    private void drawMotionOnVoxelMap(ref VoxelMap voxelMap, Motion motion) {
        RedBlackTree!(Vector2D, bool) seen;
        recurse(voxelMap, seen, voxelHash(motion.posOne), motion);
    }
}

private struct Simulator {
    private Vector!CallSign aircraft;

    @disable this(this);

    this(int numAircraft) {
        foreach (i; 0 .. numAircraft)
            aircraft.append(CallSign(i));
    }

    Vector!Aircraft simulate(double time) {
        Vector!Aircraft frame;
        for (size_t i = 0; i < aircraft.size(); i += 2) {
            frame.append(Aircraft(aircraft.at(i),
                                  Vector3D(time, cos(time) * 2 + cast(double) i * 3, 10)));
            frame.append(Aircraft(aircraft.at(i + 1),
                                  Vector3D(time, sin(time) * 2 + cast(double) i * 3, 10)));
        }
        return frame;
    }
}

final class CD : Runnable {
    bool innerBenchmarkLoop(int innerIterations) {
        return verifyResult(benchmark(innerIterations), innerIterations);
    }

    private static size_t benchmark(int numAircrafts) {
        enum numFrames = 200;
        auto simulator = Simulator(numAircrafts);
        CollisionDetector detector;

        size_t actualCollisions = 0;
        foreach (i; 0 .. numFrames) {
            const time = i / 10.0;
            Vector!Aircraft frame = simulator.simulate(time);
            Vector!Collision* collisions = detector.handleNewFrame(frame);
            actualCollisions += collisions.size();
            dispose(collisions);
        }
        return actualCollisions;
    }

    private static bool verifyResult(size_t actualCollisions, int numAircrafts) {
        if (numAircrafts == 1000)
            return actualCollisions == 14_484;
        if (numAircrafts == 500)
            return actualCollisions == 14_484;
        if (numAircrafts == 250)
            return actualCollisions == 10_830;
        if (numAircrafts == 200)
            return actualCollisions == 8655;
        if (numAircrafts == 100)
            return actualCollisions == 4305;
        if (numAircrafts == 10)
            return actualCollisions == 390;
        if (numAircrafts == 2)
            return actualCollisions == 42;

        writeln("No verification result for ", numAircrafts, " found");
        writeln("Result is: ", actualCollisions);
        return false;
    }
}
