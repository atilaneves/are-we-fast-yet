module bounce;

import benchmark;
import som.random;

private int abs(int x) {
    return x < 0 ? -x : x;
}

private struct Ball {
    int x;
    int y;
    int xVel;
    int yVel;

    this(ref Random random) {
        x = random.next() % 500;
        y = random.next() % 500;
        xVel = (random.next() % 300) - 150;
        yVel = (random.next() % 300) - 150;
    }

    bool bounce() {
        enum xLimit = 500;
        enum yLimit = 500;
        bool bounced = false;
        x += xVel;
        y += yVel;
        if (x > xLimit) {
            x = xLimit;
            xVel = 0 - abs(xVel);
            bounced = true;
        }
        if (x < 0) {
            x = 0;
            xVel = abs(xVel);
            bounced = true;
        }
        if (y > yLimit) {
            y = yLimit;
            yVel = 0 - abs(yVel);
            bounced = true;
        }
        if (y < 0) {
            y = 0;
            yVel = abs(yVel);
            bounced = true;
        }
        return bounced;
    }
}

final class Bounce : Benchmark!int {
    override int benchmark() {
        Random random;
        enum ballCount = 100;
        int bounces = 0;
        Ball[ballCount] balls;
        foreach (ref ball; balls)
            ball = Ball(random);

        foreach (j; 0 .. 50) {
            foreach (ref ball; balls) {
                if (ball.bounce())
                    bounces += 1;
            }
        }
        return bounces;
    }

    override bool verifyResult(int result) {
        return 1331 == result;
    }
}
