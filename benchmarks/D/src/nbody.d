module nbody;

import benchmark;
import core.math : sqrt;
import std.stdio : writeln;

private struct Body {
    private enum pi = 3.141592653589793;
    private enum solarMass = 4 * pi * pi;
    private enum daysPerYear = 365.24;

    double x;
    double y;
    double z;
    double vx;
    double vy;
    double vz;
    double mass;

    this(double x, double y, double z, double vx, double vy, double vz, double mass) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.vx = vx * daysPerYear;
        this.vy = vy * daysPerYear;
        this.vz = vz * daysPerYear;
        this.mass = mass * solarMass;
    }

    void offsetMomentum(double px, double py, double pz) {
        vx = 0.0 - (px / solarMass);
        vy = 0.0 - (py / solarMass);
        vz = 0.0 - (pz / solarMass);
    }

    static Body jupiter() {
        return Body(4.84143144246472090e+00, -1.16032004402742839e+00,
                        -1.03622044471123109e-01, 1.66007664274403694e-03,
                        7.69901118419740425e-03, -6.90460016972063023e-05,
                        9.54791938424326609e-04);
    }

    static Body saturn() {
        return Body(8.34336671824457987e+00, 4.12479856412430479e+00,
                        -4.03523417114321381e-01, -2.76742510726862411e-03,
                        4.99852801234917238e-03, 2.30417297573763929e-05,
                        2.85885980666130812e-04);
    }

    static Body uranus() {
        return Body(1.28943695621391310e+01, -1.51111514016986312e+01,
                        -2.23307578892655734e-01, 2.96460137564761618e-03,
                        2.37847173959480950e-03, -2.96589568540237556e-05,
                        4.36624404335156298e-05);
    }

    static Body neptune() {
        return Body(1.53796971148509165e+01, -2.59193146099879641e+01,
                        1.79258772950371181e-01, 2.68067772490389322e-03,
                        1.62824170038242295e-03, -9.51592254519715870e-05,
                        5.15138902046611451e-05);
    }

    static Body sun() {
        return Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    }
}

private struct NBodySystem {
    private Body[5] bodies;

    static NBodySystem create() {
        NBodySystem system;
        system.bodies = createBodies();
        return system;
    }

    private static Body[5] createBodies() {
        Body[5] bodies;
        bodies[0] = Body.sun();
        bodies[1] = Body.jupiter();
        bodies[2] = Body.saturn();
        bodies[3] = Body.uranus();
        bodies[4] = Body.neptune();

        double px = 0.0;
        double py = 0.0;
        double pz = 0.0;
        foreach (ref body; bodies) {
            px += body.vx * body.mass;
            py += body.vy * body.mass;
            pz += body.vz * body.mass;
        }

        bodies[0].offsetMomentum(px, py, pz);
        return bodies;
    }

    void advance(double dt) {
        foreach (i, ref iBody; bodies) {
            foreach (ref jBody; bodies[i + 1 .. $]) {
                const dx = iBody.x - jBody.x;
                const dy = iBody.y - jBody.y;
                const dz = iBody.z - jBody.z;

                const dSquared = dx * dx + dy * dy + dz * dz;
                const distance = sqrt(dSquared);
                const mag = dt / (dSquared * distance);

                iBody.vx -= dx * jBody.mass * mag;
                iBody.vy -= dy * jBody.mass * mag;
                iBody.vz -= dz * jBody.mass * mag;

                jBody.vx += dx * iBody.mass * mag;
                jBody.vy += dy * iBody.mass * mag;
                jBody.vz += dz * iBody.mass * mag;
            }
        }

        foreach (ref body; bodies) {
            body.x += dt * body.vx;
            body.y += dt * body.vy;
            body.z += dt * body.vz;
        }
    }

    double energy() {
        double e = 0.0;

        foreach (i, ref iBody; bodies) {
            e += 0.5 * iBody.mass *
                 (iBody.vx * iBody.vx + iBody.vy * iBody.vy + iBody.vz * iBody.vz);

            foreach (ref jBody; bodies[i + 1 .. $]) {
                const dx = iBody.x - jBody.x;
                const dy = iBody.y - jBody.y;
                const dz = iBody.z - jBody.z;

                const distance = sqrt(dx * dx + dy * dy + dz * dz);
                e -= (iBody.mass * jBody.mass) / distance;
            }
        }
        return e;
    }
}

final class NBody : Runnable {
    bool innerBenchmarkLoop(int innerIterations) {
        return verifyResult(run(innerIterations), innerIterations);
    }

    double run(int innerIterations) {
        auto system = NBodySystem.create();
        foreach (i; 0 .. innerIterations)
            system.advance(0.01);
        return system.energy();
    }

    bool verifyResult(double result, int innerIterations) {
        if (innerIterations == 250000)
            return result == -0.1690859889909308;
        if (innerIterations == 1)
            return result == -0.16907495402506745;

        writeln("No verification result for ", innerIterations, " found");
        writeln("Result is: ", result);
        return false;
    }
}
