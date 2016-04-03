import derelict.opencl.cl;
import std.exception : enforce, assumeUnique;

static this() {
    DerelictCL.load();
    DerelictCL.reload(CLVersion.CL12);
}

string deviceTypeNameCode() {
    string r;
    foreach(e; ["CL_DEVICE_TYPE_DEFAULT","CL_DEVICE_TYPE_CPU","CL_DEVICE_TYPE_GPU","CL_DEVICE_TYPE_ACCELERATOR","CL_DEVICE_TYPE_CUSTOM","CL_DEVICE_TYPE_ALL"]) {
        r ~= "if (type == " ~ e ~ ") return \"" ~ e ~ "\";";
    }
    return r;
}
string deviceTypeName(cl_device_type type) {
    mixin(deviceTypeNameCode);
    assert(false);
}
string clErrorNameCode() {
    string r;
    foreach(e; ["CL_SUCCESS","CL_DEVICE_NOT_FOUND","CL_DEVICE_NOT_AVAILABLE","CL_COMPILER_NOT_AVAILABLE","CL_MEM_OBJECT_ALLOCATION_FAILURE","CL_OUT_OF_RESOURCES","CL_OUT_OF_HOST_MEMORY","CL_PROFILING_INFO_NOT_AVAILABLE","CL_MEM_COPY_OVERLAP","CL_IMAGE_FORMAT_MISMATCH","CL_IMAGE_FORMAT_NOT_SUPPORTED","CL_BUILD_PROGRAM_FAILURE","CL_MAP_FAILURE","CL_MISALIGNED_SUB_BUFFER_OFFSET","CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST","CL_COMPILE_PROGRAM_FAILURE","CL_LINKER_NOT_AVAILABLE","CL_LINK_PROGRAM_FAILURE","CL_DEVICE_PARTITION_FAILED","CL_KERNEL_ARG_INFO_NOT_AVAILABLE","CL_INVALID_VALUE","CL_INVALID_DEVICE_TYPE","CL_INVALID_PLATFORM","CL_INVALID_DEVICE","CL_INVALID_CONTEXT","CL_INVALID_QUEUE_PROPERTIES","CL_INVALID_COMMAND_QUEUE","CL_INVALID_HOST_PTR","CL_INVALID_MEM_OBJECT","CL_INVALID_IMAGE_FORMAT_DESCRIPTOR","CL_INVALID_IMAGE_SIZE","CL_INVALID_SAMPLER","CL_INVALID_BINARY","CL_INVALID_BUILD_OPTIONS","CL_INVALID_PROGRAM","CL_INVALID_PROGRAM_EXECUTABLE","CL_INVALID_KERNEL_NAME","CL_INVALID_KERNEL_DEFINITION","CL_INVALID_KERNEL","CL_INVALID_ARG_INDEX","CL_INVALID_ARG_VALUE","CL_INVALID_ARG_SIZE","CL_INVALID_KERNEL_ARGS","CL_INVALID_WORK_DIMENSION","CL_INVALID_WORK_GROUP_SIZE","CL_INVALID_WORK_ITEM_SIZE","CL_INVALID_GLOBAL_OFFSET","CL_INVALID_EVENT_WAIT_LIST","CL_INVALID_EVENT","CL_INVALID_OPERATION","CL_INVALID_GL_OBJECT","CL_INVALID_BUFFER_SIZE","CL_INVALID_MIP_LEVEL","CL_INVALID_GLOBAL_WORK_SIZE","CL_INVALID_PROPERTY","CL_INVALID_IMAGE_DESCRIPTOR","CL_INVALID_COMPILER_OPTIONS","CL_INVALID_LINKER_OPTIONS","CL_INVALID_DEVICE_PARTITION_COUNT"])
    {
        r ~= "if (error == " ~ e ~ ") return \"" ~ e ~ "\";";
    }
    return r;
}
string clErrorName(cl_int error) {
    mixin(clErrorNameCode());
    assert(false);
}

cl_int cl_error;
void checkError(string file = __FILE__, size_t line = __LINE__) {
    if (cl_error == CL_SUCCESS) return;
    throw new Exception(clErrorName(cl_error), file, line);
}

struct Context {
    cl_context context;

    static auto listDevice(cl_platform_id platformArg = null, cl_device_type typeFilter = CL_DEVICE_TYPE_ALL) {
        return new class Object {
            int opApply(int delegate(cl_device_id, cl_device_type) dg) {
                if (platformArg is null) {
                    foreach(platform; Context.listPlatform) {
                        int result = opApply(platform, dg);
                        if (result != 0) return result;
                    }
                } else {
                    return opApply(platformArg, dg);
                }

                return 0;
            }

            int opApply(cl_platform_id platform, int delegate(cl_device_id, cl_device_type) dg) {
                cl_device_id[] devices;
                devices.length = 16;
                uint devicesN;
                clGetDeviceIDs(platform, typeFilter, 16, devices.ptr, &devicesN);
                devices.length = devicesN;

                foreach(device; devices) {
                    cl_device_type type;
                    clGetDeviceInfo(device, CL_DEVICE_TYPE, typeof(type).sizeof, &type, null);
                    int result = dg(device, type);
                    if (result) return result;
                }

                return 0;
            }
        };
    }

    static auto listPlatform() {
        return new class Object {
            int opApply(int delegate(cl_platform_id) dg) {
                cl_platform_id[] platforms;
                platforms.length = 16;
                uint platformsN;
                clGetPlatformIDs(16, platforms.ptr, &platformsN);
                platforms.length = platformsN;

                foreach(platform; platforms) {
                    int result = dg(platform);
                    if (result != 0) return result;
                }

                return 0;
            }
        };
    }

    static cl_device_id selectFirstDevice(cl_device_type typeFilter = CL_DEVICE_TYPE_ALL, cl_platform_id platformFilter = null) {
        foreach(device, type; listDevice(platformFilter, typeFilter)) {
            return device;
        }
        return null;
    }

    this(cl_device_id device) {
        context = clCreateContext(null, 1, &device, null, null, &cl_error);
        checkError();
    }

    @disable this(this);

    ~this() {
        if (context is null) return;
        clReleaseContext(context);
    }
}

struct CommandQueue {
    cl_command_queue queue;

    this(ref Context context, cl_device_id device) {
        queue = clCreateCommandQueue(context.context, device, 0, &cl_error);
        checkError();
    }

    @disable this(this);

    ~this() {
        if (queue is null) return;
        clReleaseCommandQueue(queue);
    }

    void enqueueNDRange(ref Kernel kernel, cl_device_id device, size_t[] global, size_t[] local) {
        import std.math;

        assert(global.length <= 3);
        assert(global.length == local.length || local.ptr is null);

        cl_error = clEnqueueNDRangeKernel(queue, kernel.kernel, cast(uint) global.length, null, global.ptr, local.ptr, 0, null, null);
        checkError();
    }

    void enqueueReadBuffer(ref Mem buffer, size_t offset, size_t size, void* dest) {
        cl_error = clEnqueueReadBuffer(queue, buffer.buffer, CL_FALSE, offset, size, dest, 0, null, null);
        checkError();
    }

    void finish() {
        cl_error = clFinish(queue);
        checkError();
    }
};

struct Program {
    cl_program program;
    this(ref Context context, cl_device_id device, string source) {
        import std.string;
        import std.stdio;

        const(char)*[] lines = [source.toStringz()];
        program = clCreateProgramWithSource(context.context, 1, lines.ptr, null, &cl_error);
        checkError();

        cl_error = clBuildProgram(program, 0, null, null, null, null);
        {
            auto cl_error_prev = cl_error; scope(exit) cl_error = cl_error_prev;
            char[] buffer;
            buffer.length = 4096;
            size_t lengthOut;
            cl_error = clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, buffer.length, buffer.ptr, &lengthOut);
            checkError();
            if (lengthOut > 0) {
                writeln(assumeUnique(buffer)[0..lengthOut]);
            }
        }
        checkError();
    }

    @disable this(this);

    ~this() {
        if (program is null) return;
        clReleaseProgram(program);
    }
};

struct Kernel {
    cl_kernel kernel;
    this(ref Program program, string name) {
        import std.string;

        kernel = clCreateKernel(program.program, name.toStringz, &cl_error);
        checkError();
    }

    @disable this(this);

    ~this() {
        if (kernel is null) return;
        clReleaseKernel(kernel);
    }

    void setArg(T)(uint index, const(T) value) {
        cl_error = clSetKernelArg(kernel, index, T.sizeof, &value);
        checkError();
    }
}

struct Mem {
    cl_mem buffer;
    this(ref Context context, cl_mem_flags flags, size_t size) {
        buffer = clCreateBuffer(context.context, flags, size, null, &cl_error);
        checkError();
    }

    @disable this(this);

    ~this() {
        if (buffer is null) return;
        clReleaseMemObject(buffer);
    }
};
