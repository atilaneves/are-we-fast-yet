module richards;

import benchmark;
import memory;
import som.error;
import std.stdio : writeln;

private class RBObject : TrackedObject {
    enum idler = 0;
    enum worker = 1;
    enum handlerA = 2;
    enum handlerB = 3;
    enum deviceA = 4;
    enum deviceB = 5;
    enum numTypes = 6;

    enum devicePacketKind = 0;
    enum workPacketKind = 1;

    enum Packet noWork = null;
    enum TaskControlBlock noTask = null;

    Packet append(Packet packet, Packet queueHead) {
        packet.setLink(noWork);
        if (noWork is queueHead)
            return packet;

        Packet mouse = queueHead;
        Packet link;
        while (noWork !is (link = mouse.getLink()))
            mouse = link;

        mouse.setLink(packet);
        return queueHead;
    }
}

private class TaskState : RBObject {
    private bool packetPending_;
    private bool taskWaiting_;
    private bool taskHolding_;

    bool isPacketPending() const {
        return packetPending_;
    }

    bool isTaskHolding() const {
        return taskHolding_;
    }

    bool isTaskWaiting() const {
        return taskWaiting_;
    }

    void setTaskHolding(bool b) {
        taskHolding_ = b;
    }

    void setTaskWaiting(bool b) {
        taskWaiting_ = b;
    }

    void setPacketPending(bool b) {
        packetPending_ = b;
    }

    void packetPending() {
        packetPending_ = true;
        taskWaiting_ = false;
        taskHolding_ = false;
    }

    void running() {
        packetPending_ = taskWaiting_ = taskHolding_ = false;
    }

    void waiting() {
        packetPending_ = taskHolding_ = false;
        taskWaiting_ = true;
    }

    void waitingWithPacket() {
        taskHolding_ = false;
        taskWaiting_ = packetPending_ = true;
    }

    bool isTaskHoldingOrWaiting() const {
        return taskHolding_ || (!packetPending_ && taskWaiting_);
    }

    bool isWaitingWithPacket() const {
        return packetPending_ && taskWaiting_ && !taskHolding_;
    }

    static TaskState createRunning() {
        auto t = make!TaskState;
        t.running();
        return t;
    }

    static TaskState createWaiting() {
        auto t = make!TaskState;
        t.waiting();
        return t;
    }

    static TaskState createWaitingWithPacket() {
        auto t = make!TaskState;
        t.waitingWithPacket();
        return t;
    }
}

private final class DeviceTaskDataRecord : RBObject {
    private Packet pending = noWork;

    Packet getPending() {
        return pending;
    }

    void setPending(Packet packet) {
        pending = packet;
    }
}

private final class HandlerTaskDataRecord : RBObject {
    private Packet workIn_ = noWork;
    private Packet deviceIn_ = noWork;

    Packet deviceIn() {
        return deviceIn_;
    }

    void deviceIn(Packet aPacket) {
        deviceIn_ = aPacket;
    }

    void deviceInAdd(Packet packet) {
        deviceIn_ = append(packet, deviceIn_);
    }

    Packet workIn() {
        return workIn_;
    }

    void workIn(Packet aWorkQueue) {
        workIn_ = aWorkQueue;
    }

    void workInAdd(Packet packet) {
        workIn_ = append(packet, workIn_);
    }
}

private final class IdleTaskDataRecord : RBObject {
    private int control = 1;
    private int count = 10_000;

    int getControl() const {
        return control;
    }

    void setControl(int aNumber) {
        control = aNumber;
    }

    int getCount() const {
        return count;
    }

    void setCount(int aCount) {
        count = aCount;
    }
}

private final class Packet : RBObject {
    enum dataSize = 4;

    private Packet link;
    private int identity;
    private int kind;
    private int datum;
    private int[dataSize] data;

    this(Packet link, int identity, int kind) {
        this.link = link;
        this.identity = identity;
        this.kind = kind;
    }

    ref int[dataSize] getData() return {
        return data;
    }

    int getDatum() const {
        return datum;
    }

    void setDatum(int someData) {
        datum = someData;
    }

    int getIdentity() const {
        return identity;
    }

    void setIdentity(int anIdentity) {
        identity = anIdentity;
    }

    int getKind() const {
        return kind;
    }

    Packet getLink() {
        return link;
    }

    void setLink(Packet aLink) {
        link = aLink;
    }
}

private final class TaskControlBlock : TaskState {
    private TaskControlBlock link;
    private int identity;
    private int priority;
    private Packet input;
    private TaskControlBlock delegate(Packet work, RBObject word) function_;
    private RBObject handle;

    this(TaskControlBlock aLink, int anIdentity, int aPriority,
         Packet anInitialWorkQueue, TaskState anInitialState,
         TaskControlBlock delegate(Packet work, RBObject word) aBlock,
         RBObject aPrivateData) {
        link = aLink;
        identity = anIdentity;
        priority = aPriority;
        input = anInitialWorkQueue;
        setPacketPending(anInitialState.isPacketPending());
        setTaskWaiting(anInitialState.isTaskWaiting());
        setTaskHolding(anInitialState.isTaskHolding());
        function_ = aBlock;
        handle = aPrivateData;
    }

    int getIdentity() const {
        return identity;
    }

    TaskControlBlock getLink() {
        return link;
    }

    int getPriority() const {
        return priority;
    }

    TaskControlBlock addInputAndCheckPriority(Packet packet, TaskControlBlock oldTask) {
        if (noWork is input) {
            input = packet;
            setPacketPending(true);
            if (priority > oldTask.getPriority())
                return this;
        } else {
            input = append(packet, input);
        }
        return oldTask;
    }

    TaskControlBlock runTask() {
        Packet message;
        if (isWaitingWithPacket()) {
            message = input;
            input = message.getLink();
            if (noWork is input)
                running();
            else
                packetPending();
        } else {
            message = noWork;
        }
        return function_(message, handle);
    }
}

private final class WorkerTaskDataRecord : RBObject {
    private int destination = handlerA;
    private int count;

    int getCount() const {
        return count;
    }

    void setCount(int aCount) {
        count = aCount;
    }

    int getDestination() const {
        return destination;
    }

    void setDestination(int aHandler) {
        destination = aHandler;
    }
}

private final class Scheduler : RBObject {
    private TaskControlBlock taskList = noTask;
    private TaskControlBlock currentTask = noTask;
    private int currentTaskIdentity;
    private TaskControlBlock[numTypes] taskTable;

    private int queuePacketCount;
    private int holdCount;
    private int layout;

    private enum tracing = false;

    void createDevice(int identity, int priority, Packet workPacket, TaskState state) {
        auto data = make!DeviceTaskDataRecord;

        createTask(identity, priority, workPacket, state, &deviceTask, data);
    }

    TaskControlBlock deviceTask(Packet workArg, RBObject wordArg) {
        auto dataRecord = cast(DeviceTaskDataRecord) wordArg;
        Packet functionWork = workArg;
        if (noWork is functionWork) {
            functionWork = dataRecord.getPending();
            if (noWork is functionWork)
                return markWaiting();
            dataRecord.setPending(noWork);
            return queuePacket(functionWork);
        }
        dataRecord.setPending(functionWork);
        static if (tracing)
            trace(functionWork.getDatum());
        return holdSelf();
    }

    void createHandler(int identity, int priority, Packet workPaket, TaskState state) {
        auto data = make!HandlerTaskDataRecord;

        createTask(identity, priority, workPaket, state, &handlerTask, data);
    }

    TaskControlBlock handlerTask(Packet work, RBObject word) {
        auto dataRecord = cast(HandlerTaskDataRecord) word;
        if (noWork !is work) {
            if (workPacketKind == work.getKind())
                dataRecord.workInAdd(work);
            else
                dataRecord.deviceInAdd(work);
        }

        Packet workPacket = dataRecord.workIn();
        if (noWork is workPacket)
            return markWaiting();

        const count = workPacket.getDatum();
        if (count >= Packet.dataSize) {
            dataRecord.workIn(workPacket.getLink());
            return queuePacket(workPacket);
        }

        Packet devicePacket = dataRecord.deviceIn();
        if (noWork is devicePacket)
            return markWaiting();

        dataRecord.deviceIn(devicePacket.getLink());
        devicePacket.setDatum(workPacket.getData()[count]);
        workPacket.setDatum(count + 1);
        return queuePacket(devicePacket);
    }

    void createIdler(int identity, int priority, Packet work, TaskState state) {
        auto data = make!IdleTaskDataRecord;

        createTask(identity, priority, work, state, &idleTask, data);
    }

    TaskControlBlock idleTask(Packet, RBObject wordArg) {
        auto dataRecord = cast(IdleTaskDataRecord) wordArg;
        dataRecord.setCount(dataRecord.getCount() - 1);
        if (0 == dataRecord.getCount())
            return holdSelf();

        if (0 == (dataRecord.getControl() & 1)) {
            dataRecord.setControl(dataRecord.getControl() / 2);
            return release(deviceA);
        }
        dataRecord.setControl((dataRecord.getControl() / 2) ^ 53_256);
        return release(deviceB);
    }

    Packet createPacket(Packet link, int identity, int kind) {
        return make!Packet(link, identity, kind);
    }

    void createTask(int identity, int priority, Packet work, TaskState state,
                    TaskControlBlock delegate(Packet work, RBObject word) aBlock,
                    RBObject data) {
        auto t = make!TaskControlBlock(taskList, identity, priority, work, state,
                                       aBlock, data);
        taskList = t;
        taskTable[identity] = t;
    }

    void createWorker(int identity, int priority, Packet workPaket, TaskState state) {
        auto dataRecord = make!WorkerTaskDataRecord;

        createTask(identity, priority, workPaket, state, &workerTask, dataRecord);
    }

    TaskControlBlock workerTask(Packet work, RBObject word) {
        auto data = cast(WorkerTaskDataRecord) word;
        if (noWork is work)
            return markWaiting();

        data.setDestination((handlerA == data.getDestination()) ? handlerB : handlerA);
        work.setIdentity(data.getDestination());
        work.setDatum(0);
        foreach (i; 0 .. Packet.dataSize) {
            data.setCount(data.getCount() + 1);
            if (data.getCount() > 26)
                data.setCount(1);
            work.getData()[i] = 65 + data.getCount() - 1;
        }
        return queuePacket(work);
    }

    bool start() {
        Packet workQ;

        createIdler(idler, 0, noWork, TaskState.createRunning());

        workQ = createPacket(noWork, worker, workPacketKind);
        workQ = createPacket(workQ, worker, workPacketKind);

        createWorker(worker, 1000, workQ, TaskState.createWaitingWithPacket());

        workQ = createPacket(noWork, deviceA, devicePacketKind);
        workQ = createPacket(workQ, deviceA, devicePacketKind);
        workQ = createPacket(workQ, deviceA, devicePacketKind);

        createHandler(handlerA, 2000, workQ, TaskState.createWaitingWithPacket());

        workQ = createPacket(noWork, deviceB, devicePacketKind);
        workQ = createPacket(workQ, deviceB, devicePacketKind);
        workQ = createPacket(workQ, deviceB, devicePacketKind);

        createHandler(handlerB, 3000, workQ, TaskState.createWaitingWithPacket());

        createDevice(deviceA, 4000, noWork, TaskState.createWaiting());
        createDevice(deviceB, 5000, noWork, TaskState.createWaiting());

        schedule();

        return queuePacketCount == 23_246 && holdCount == 9297;
    }

    TaskControlBlock findTask(int identity) {
        TaskControlBlock t = taskTable[identity];
        if (noTask is t)
            throw new SomError("findTask failed");
        return t;
    }

    TaskControlBlock holdSelf() {
        holdCount = holdCount + 1;
        currentTask.setTaskHolding(true);
        return currentTask.getLink();
    }

    TaskControlBlock queuePacket(Packet packet) {
        TaskControlBlock t = findTask(packet.getIdentity());
        if (noTask is t)
            return noTask;

        queuePacketCount = queuePacketCount + 1;

        packet.setLink(noWork);
        packet.setIdentity(currentTaskIdentity);
        return t.addInputAndCheckPriority(packet, currentTask);
    }

    TaskControlBlock release(int identity) {
        TaskControlBlock t = findTask(identity);
        if (noTask is t)
            return noTask;

        t.setTaskHolding(false);
        if (t.getPriority() > currentTask.getPriority())
            return t;
        return currentTask;
    }

    void trace(int id) {
        layout = layout - 1;
        if (0 >= layout) {
            writeln();
            layout = 50;
        }
        writeln(id);
    }

    TaskControlBlock markWaiting() {
        currentTask.setTaskWaiting(true);
        return currentTask;
    }

    void schedule() {
        currentTask = taskList;
        while (noTask !is currentTask) {
            if (currentTask.isTaskHoldingOrWaiting()) {
                currentTask = currentTask.getLink();
            } else {
                currentTaskIdentity = currentTask.getIdentity();
                static if (tracing)
                    trace(currentTaskIdentity);
                currentTask = currentTask.runTask();
            }
        }
    }
}

final class Richards : Benchmark {
    override Any benchmark() {
        auto scheduler = make!Scheduler;
        const result = scheduler.start();
        ObjectTracker.releaseAll();
        return Any(result);
    }

    override bool verifyResult(Any result) {
        return result.get!bool;
    }
}
