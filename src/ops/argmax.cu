/* Copyright 2023 CMU, Facebook, LANL, MIT, NVIDIA, and Stanford (alphabetical)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "flexflow/ffconst_utils.h"
#include "flexflow/ops/argmax.h"
#include "flexflow/utils/cuda_helper.h"

namespace FlexFlow {

__global__ void
    half_2_float_array(half *ptr, float *ptr_f, int num_of_elements) {
  CUDA_KERNEL_LOOP(i, num_of_elements) {
    ptr_f[i] = __half2float(ptr[i]);
  }
}

/*static*/
template <typename DT>
void ArgMax::forward_kernel(ArgMaxMeta const *m,
                            DT *input_ptr,
                            int *indices_ptr,
                            DT *prob_ptr,
                            int *parent,
                            int const length,
                            int const batch_size,
                            cudaStream_t stream) {

  checkCUDNN(cudnnSetStream(m->handle.dnn, stream));
  DT alpha = 1.0f, beta = 0.0f;
  if (m->beam_search) {
    // set all parents id zero in arg top1 case.
    checkCUDA(cudaMemset(parent, 0, batch_size * sizeof(int)));
  }
  checkCUDNN(cudnnReduceTensor(m->handle.dnn,
                               m->reduceMaxDesc,
                               indices_ptr /*indices*/,
                               batch_size * sizeof(int) /*indicesSizeInBytes*/,
                               m->handle.workSpace,
                               m->handle.workSpaceSize,
                               &alpha,
                               m->inputTensor,
                               input_ptr,
                               &beta,
                               m->outputTensor,
                               prob_ptr));
}

/*static*/
void ArgMax::forward_kernel_wrapper(ArgMaxMeta const *m,
                                    GenericTensorAccessorW const &input,
                                    GenericTensorAccessorW const &indices,
                                    GenericTensorAccessorW const &value,
                                    GenericTensorAccessorW const &parent) {
  cudaStream_t stream;
  checkCUDA(get_legion_stream(&stream));

  cudaEvent_t t_start, t_end;
  if (m->profiling) {
    cudaEventCreate(&t_start);
    cudaEventCreate(&t_end);
    cudaEventRecord(t_start, stream);
  }
  int length = input.domain.hi()[0] - input.domain.lo()[0] + 1;
  int batch_size = input.domain.get_volume() / length;

  if (input.data_type == DT_HALF) {
    ArgMax::forward_kernel<half>(m,
                                 input.get_half_ptr(),
                                 indices.get_int32_ptr(),
                                 value.get_half_ptr(),
                                 m->beam_search ? parent.get_int32_ptr()
                                                : nullptr,
                                 length,
                                 batch_size,
                                 stream);
    if (m->beam_search) {
      half_2_float_array<<<GET_BLOCKS(batch_size),
                           CUDA_NUM_THREADS,
                           0,
                           stream>>>(
          value.get_half_ptr(), m->probs, batch_size);
    }

  } else if (input.data_type == DT_FLOAT) {
    ArgMax::forward_kernel<float>(m,
                                  input.get_float_ptr(),
                                  indices.get_int32_ptr(),
                                  value.get_float_ptr(),
                                  m->beam_search ? parent.get_int32_ptr()
                                                 : nullptr,
                                  length,
                                  batch_size,
                                  stream);
  } else {
    assert(false && "Unsupported data type");
  }

  if (m->profiling) {
    cudaEventRecord(t_end, stream);
    checkCUDA(cudaEventSynchronize(t_end));
    float elapsed = 0;
    checkCUDA(cudaEventElapsedTime(&elapsed, t_start, t_end));
    cudaEventDestroy(t_start);
    cudaEventDestroy(t_end);
    printf("[ArgMax] forward time = %.2lfms\n", elapsed);
  }
}

ArgMaxMeta::ArgMaxMeta(FFHandler handler,
                       Op const *op,
                       Legion::Domain const &input_domain,
                       Legion::Domain const &output_domain,
                       GenericTensorAccessorW input)
    : OpMeta(handler, op) {
  DataType data_type = op->data_type;
  checkCUDNN(cudnnCreateTensorDescriptor(&inputTensor));
  checkCUDNN(cudnnCreateTensorDescriptor(&outputTensor));
  checkCUDNN(cudnnCreateReduceTensorDescriptor(&reduceMaxDesc));

  // Float and Half use save type, according to
  // https://docs.nvidia.com/deeplearning/cudnn/api/index.html#cudnnReduceTensor:~:text=not%20coordinate%20tuples.-,The%20data%20types%20of%20the%20tensors,.,-Note%3A
  cudnnDataType_t cudnn_data_type = CUDNN_DATA_FLOAT;

  checkCUDNN(
      cudnnSetReduceTensorDescriptor(reduceMaxDesc,
                                     CUDNN_REDUCE_TENSOR_MAX,
                                     cudnn_data_type,
                                     CUDNN_PROPAGATE_NAN,
                                     CUDNN_REDUCE_TENSOR_FLATTENED_INDICES,
                                     CUDNN_32BIT_INDICES));
  checkCUDNN(cudnnSetTensorDescriptorFromDomain(
      outputTensor, output_domain, data_type));
  checkCUDNN(
      cudnnSetTensorDescriptorFromDomain(inputTensor, input_domain, data_type));

  checkCUDA(cudaMalloc(&probs, sizeof(float) * BatchConfig::MAX_NUM_TOKENS));
}

}; // namespace FlexFlow