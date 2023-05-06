#ifndef _FLEXFLOW_RUNTIME_SRC_PARALLEL_TENSOR_LEGION_BACKING_H
#define _FLEXFLOW_RUNTIME_SRC_PARALLEL_TENSOR_LEGION_BACKING_H

#include "legion.h"
#include "utils/visitable.h"
#include "kernels/per_device_op_state.h"
#include "parallel_computation_graph.h"

namespace FlexFlow {

struct OperatorLegionBacking {
  stack_vector<PerDeviceOpState, MAX_NUM_WORKERS> meta;
#ifdef FF_USE_NCCL
  ncclUniqueId ncclId;
#endif
};

struct mapping_id_t : strong_typedef<mapping_id_t, size_t> {
  using strong_typedef::strong_typedef;
};

struct ParallelTensorLegionBacking : use_visitable_eq<ParallelTensorLegionBacking> {
public:
  ParallelTensorLegionBacking() = delete;
  ParallelTensorLegionBacking(mapping_id_t mapping_id,
                              Legion::IndexSpace const &parallel_is,
                              Legion::LogicalRegion const &region,
                              Legion::LogicalRegion const &region_grad,
                              Legion::LogicalPartition const &part,
                              Legion::LogicalPartition const &part_grad,
                              Legion::PhysicalRegion const &phyical_region);

public:
  mapping_id_t mapping_id;
  Legion::IndexSpace parallel_is;
  Legion::LogicalRegion region;
  Legion::LogicalRegion region_grad;
  Legion::LogicalPartition part;
  Legion::LogicalPartition part_grad;
  Legion::PhysicalRegion physical_region;
};

struct RuntimeBacking {
  OperatorLegionBacking at(operator_guid_t const &) const;
  ParallelTensorLegionBacking at(parallel_tensor_guid_t const &) const;
public:
  LegionConfig legion_config;
  std::unordered_map<operator_guid_t, OperatorLegionBacking> op_backing;
  std::unordered_map<parallel_tensor_guid_t, ParallelTensorLegionBacking> parallel_tensor_backing;
};
}

VISITABLE_STRUCT(::FlexFlow::ParallelTensorLegionBacking, parallel_is, region, region_grad, part, part_grad, physical_region);


#endif