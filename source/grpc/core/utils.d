module grpc.core.utils;
import interop.headers;
import interop.functors;
import grpc.logger;
import std.experimental.allocator : theAllocator, makeArray, dispose;
public import core.time;

string slice_to_string(grpc_slice slice) {
    return slice_to_type!string(slice);
}

auto ref slice_to_type(T)(grpc_slice slice) 
if(__traits(isPOD, T) && __traits(compiles, cast(T)[0x01, 0x02])) {
    if (GRPC_SLICE_LENGTH(slice) != 0) {
        ubyte[] data = theAllocator.makeArray!ubyte(GRPC_SLICE_START_PTR(slice)[0..GRPC_SLICE_LENGTH(slice)]);
        DEBUG!"MAKE SURE TO FREE THIS ARRAY: %x"(data.ptr);
        DEBUG!"data size: %d"(data.length);
        return cast(T)data;
    }

    return null;
    
}

string byte_buffer_to_string(grpc_byte_buffer* bytebuf) {
        return byte_buffer_to_type!string(bytebuf);
}

auto ref byte_buffer_to_type(T)(grpc_byte_buffer* bytebuf) {
        grpc_byte_buffer_reader reader;
        grpc_byte_buffer_reader_init(&reader, bytebuf);
        grpc_slice slices = grpc_byte_buffer_reader_readall(&reader);
        grpc_byte_buffer_reader_destroy(&reader);
        scope(exit) grpc_slice_unref(slices);
        return slice_to_type!T(slices);
}

/* ensure that you unref after this.. don't want to keep a slice around too long */

grpc_slice string_to_slice(string _string) {
    import std.string : toStringz;
    grpc_slice slice = grpc_slice_from_copied_string(_string.toStringz);
    return slice;
}

grpc_slice type_to_slice(T)(T type) {
    grpc_slice slice = grpc_slice_from_copied_buffer(cast(const(char*))type.ptr, type.length);
    return slice;
}
    
gpr_timespec durtotimespec(Duration time) nothrow {
    gpr_timespec t;
    t.clock_type = GPR_CLOCK_MONOTONIC; 
    MonoTime curr = MonoTime.currTime;
    auto _time = curr + time;
    import std.stdio;

    auto nsecs = ticksToNSecs(_time.ticks).nsecs;

    nsecs.split!("seconds", "nsecs")(t.tv_sec, t.tv_nsec);
    
    return t;
}

Duration timespectodur(gpr_timespec time) nothrow {
    return time.tv_sec.seconds + time.tv_nsec.nsecs;
}

import core.memory : GC;
void doNotMoveObject(void* ptr, size_t len) @trusted nothrow {
    GC.addRange(ptr, len);
    GC.setAttr(cast(void*)ptr, GC.BlkAttr.NO_MOVE);
    GC.addRoot(ptr);
}

void okToMoveObject(void* ptr) @trusted nothrow {
    GC.removeRoot(ptr);
    GC.clrAttr(cast(void*)ptr, GC.BlkAttr.NO_MOVE);
    GC.removeRange(ptr);
}
