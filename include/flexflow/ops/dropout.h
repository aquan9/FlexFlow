#ifndef _FLEXFLOW_DROPOUT_H
#define _FLEXFLOW_DROPOUT_H

#include "flexflow/model.h"

namespace FlexFlow {

class DropoutMeta;
class Dropout : public Op {
public:
  Dropout(FFModel& model,
          const ParallelTensor input,
          float rate,
          unsigned long long seed,
          const char* name);
  void init(const FFModel&) override;
  void forward(const FFModel&) override;
  void backward(const FFModel&) override;
  void print_layer(const FFModel& model) override {assert(0);}

  static OpMeta* init_task(const Legion::Task *task,
                           const std::vector<Legion::PhysicalRegion> &regions,
                           Legion::Context ctx, Legion::Runtime *runtime);
  static void forward_task(const Legion::Task *task,
                           const std::vector<Legion::PhysicalRegion> &regions,
                           Legion::Context ctx, Legion::Runtime *runtime);
  static void backward_task(const Legion::Task *task,
                            const std::vector<Legion::PhysicalRegion> &regions,
                            Legion::Context ctx, Legion::Runtime *runtime);
#if defined (FF_USE_CUDA) || defined (FF_USE_HIP_CUDA)
  static void forward_kernel(DropoutMeta *m,
                             float const *input_ptr,
                             float *output_ptr,
                             cudaStream_t stream);
  static void backward_kernel(DropoutMeta *m,
                              float const *output_grad_ptr,
                              float *input_grad_ptr,
                              cudaStream_t stream);
#else
  static void forward_kernel(DropoutMeta *m,
                             float const *input_ptr,
                             float *output_ptr,
                             hipStream_t stream);
  static void backward_kernel(DropoutMeta *m,
                              float const *output_grad_ptr,
                              float *input_grad_ptr,
                              hipStream_t stream);
#endif
  bool measure_operator_cost(Simulator* sim,
                             const ParallelConfig& pc,
                             CostMetrics& cost_metrics) const override;
public:
  float rate;
  unsigned long long seed;
};

class DropoutMeta : public OpMeta {
public:
  DropoutMeta(FFHandler handle,
              const Dropout* dropout,
              Legion::Memory gpu_mem,
              const Legion::Domain& output_domain);
  ~DropoutMeta(void);
  Realm::RegionInstance reserveInst;
#if defined (FF_USE_CUDA) || defined (FF_USE_HIP_CUDA)
  cudnnTensorDescriptor_t inputTensor, outputTensor;
  cudnnDropoutDescriptor_t dropoutDesc;
#else
  miopenTensorDescriptor_t inputTensor, outputTensor;
  miopenDropoutDescriptor_t dropoutDesc;
#endif
  void *reserveSpace, *dropoutStates;
  size_t reserveSpaceSize, dropoutStateSize;
};

}; // namespace FlexFlow

#endif