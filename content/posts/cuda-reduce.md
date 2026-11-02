+++
title = "CUDA 归约 kernel"
date = 2026-11-02
description = "把并行归约收成一个 kernel，写清分支、共享内存和最后一轮 warp 各在修什么。这版还没上 Nsight。"
summary = "把并行归约收成一个 kernel，写清分支、共享内存和最后一轮 warp 各在修什么。这版还没上 Nsight。"
stage = "gpu"
tags = ["CUDA", "GPU"]
aliases = ["/posts/ruduce/"]
+++

归约是把一块数组收成一个值，比如求和。串行写法只有一个线程在干活，开再大的 grid 也没有并行。这篇把我准备拿去跑的版本收成一个 kernel，并写清每一段在修什么。

顺序参照 Mark Harris 的 [Optimizing Parallel Reduction in CUDA](https://developer.download.nvidia.com/assets/cuda/files/reduction.pdf)。下面的 kernel 是按这个顺序自己收的一版，不是文档里的代码。它还没上 Nsight Compute。

## 先丢掉的写法

一个线程扫完整段数组，其余线程空转。结果是对的，但和 GPU 无关。

```cuda
__global__ void reduce_serial(const float* in, float* out, int n) {
    if (blockIdx.x != 0 || threadIdx.x != 0) return;
    float sum = 0.f;
    for (int i = 0; i < n; ++i) sum += in[i];
    *out = sum;
}
```

另一类常见写法让 `tid % (2 * stride) == 0` 的线程跨步相加，stride 从 1 开始翻倍。同一 warp 里有的线程进分支、有的不进，shared memory 也在跳着读。

## 准备拿去跑的版本

每个线程先从全局内存读两个元素，加完再写入 shared memory。block 里的循环用连续地址：stride 从 `blockDim/2` 往下减，前 `stride` 个线程各自加上右边那个元素。stride 大于 32 才进循环，这样参与的线程读的是连续地址，也避开 shared memory bank conflict。

剩下 32 个线程刚好是一个 warp，不再 `__syncthreads`。这里把 shared memory 标成 volatile：编译器可能把 `smem[tid]` 留在寄存器里，同 warp 其他线程已经改了 shared memory，它还在用旧值。

```cuda
__global__ void reduce(const float* in, float* partial, int n) {
    extern __shared__ float smem[];
    const int tid = threadIdx.x;
    const int i = blockIdx.x * (blockDim.x * 2) + tid;

    float sum = 0.f;
    if (i < n) sum = in[i];
    if (i + blockDim.x < n) sum += in[i + blockDim.x];
    smem[tid] = sum;
    __syncthreads();

    for (int stride = blockDim.x / 2; stride > 32; stride >>= 1) {
        if (tid < stride) smem[tid] += smem[tid + stride];
        __syncthreads();
    }

    if (tid < 32) {
        volatile float* v = smem;
        if (blockDim.x >= 64) v[tid] += v[tid + 32];
        v[tid] += v[tid + 16];
        v[tid] += v[tid + 8];
        v[tid] += v[tid + 4];
        v[tid] += v[tid + 2];
        v[tid] += v[tid + 1];
    }

    if (tid == 0) partial[blockIdx.x] = smem[0];
}
```

`blockDim.x` 需要是不小于 64 的 2 的幂。我打算用 256。启动时每个 block 处理 `2 * threads` 个元素，动态共享内存是每个线程一个 float：

```cuda
int threads = 256;
int blocks = (n + threads * 2 - 1) / (threads * 2);
reduce<<<blocks, threads, threads * sizeof(float)>>>(in, partial, n);
```

`partial` 的长度是 block 数，不是最终结果。多卡还没进这道题，这里只是多个 block。部分和我打算拷回主机再加一次，不先写一个递归 kernel。浮点加法的顺序和纯串行不同，所以即使用同一个数组，bit 级结果也不必和 CPU 循环一致。

## 下一步想换掉的最后一轮

最后 32 个线程可以不碰 shared memory，用 warp shuffle 把值收上来。返回值只在 lane 0 有意义。整个 block 还要把每个 warp 的 lane 0 再加一次。`0xffffffff` 表示这个 warp 的 32 个线程都参加；有线程提前退出时不能这么写。

```cuda
__device__ float warp_sum(float v) {
#pragma unroll
    for (int offset = 16; offset > 0; offset >>= 1) {
        v += __shfl_down_sync(0xffffffff, v, offset);
    }
    return v;
}
```

这版我还没替换进上面的 kernel，也没和 shared memory 版比过时间。

## 还没测

- 用全 1 数组核对，长度取 `1 << 20` 时期望和是 `1048576`。这能抓越界，抓不住浮点顺序问题。
- `n` 不是 `2 * threads` 的整数倍时，尾块里读不到的元素按 0 加。这个边界还没跑。
- 在 Nsight Compute 里看 `n = 1 << 24` 的 DRAM 吞吐，对照这块 GPU 的理论带宽。没看之前，我不写「这版已经够快」。
- `atomicAdd` 到一个全局地址也能得到和，但会把带宽问题藏起来。不用它当这道题的优化。
