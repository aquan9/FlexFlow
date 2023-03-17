#ifndef _FLEXFLOW_GROUPBY_ATTRS_H
#define _FLEXFLOW_GROUPBY_ATTRS_H

#include "op-meta/parallel_tensor_shape.h"
#include "binary_op.h"
#include "visit_struct/visit_struct.hpp"

namespace FlexFlow {

struct Group_byAttrs : public BinaryOpAttrs {
public:
  ParallelTensorShape output_shape(ParallelTensorShape const &, ParallelTensorShape const &) const override;
  OperatorType op_type() const override;
public:
  int n;
  float alpha;
};
bool operator==(Group_byAttrs const &, Group_byAttrs const &);

}

VISITABLE_STRUCT(::FlexFlow::Group_byAttrs, n, alpha);

namespace std {
template <>
struct hash<::FlexFlow::Group_byAttrs> {
  size_t operator()(::FlexFlow::Group_byAttrs const &) const;
};
}

#endif 