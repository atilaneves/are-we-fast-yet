module towers;

import benchmark;
import memory;
import som.error;

private struct TowersDisk {
    private int size;
    private TowersDisk* next;

    this(int size) {
        this.size = size;
    }

    version (ManualMemory) ~this() {
        dispose(next);
    }

    int getSize() const {
        return size;
    }

    TowersDisk* getNext() {
        return next;
    }

    void setNext(TowersDisk* disk) {
        next = disk;
    }
}

final class Towers : Benchmark {
    private TowersDisk*[3] piles;
    private int movesDone;

    override Any benchmark() {
        piles = typeof(piles).init;
        buildTowerAt(0, 13);
        movesDone = 0;
        moveDisks(13, 0, 1);

        foreach (ref disk; piles)
            dispose(disk);
        return Any(movesDone);
    }

    private void pushDisk(TowersDisk* disk, int pile) {
        TowersDisk* top = piles[pile];
        if (top !is null && disk.getSize() >= top.getSize())
            throw new SomError("Cannot put a big disk on a smaller one");

        disk.setNext(top);
        piles[pile] = disk;
    }

    private TowersDisk* popDiskFrom(int pile) {
        TowersDisk* top = piles[pile];
        if (top is null)
            throw new SomError("Attempting to remove a disk from an empty pile");

        piles[pile] = top.getNext();
        top.setNext(null);
        return top;
    }

    private void moveTopDisk(int fromPile, int toPile) {
        pushDisk(popDiskFrom(fromPile), toPile);
        movesDone += 1;
    }

    private void buildTowerAt(int pile, int disks) {
        for (int i = disks; i >= 0; i -= 1)
            pushDisk(makePtr!TowersDisk(i), pile);
    }

    private void moveDisks(int disks, int fromPile, int toPile) {
        if (disks == 1) {
            moveTopDisk(fromPile, toPile);
        } else {
            const otherPile = (3 - fromPile) - toPile;
            moveDisks(disks - 1, fromPile, otherPile);
            moveTopDisk(fromPile, toPile);
            moveDisks(disks - 1, otherPile, toPile);
        }
    }

    override bool verifyResult(Any result) {
        return 8191 == result.get!int;
    }
}
