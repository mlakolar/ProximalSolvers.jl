define float @julia__maxabs_diff_607({}* noundef nonnull align 16 dereferenceable(40) %0, {}* noundef nonnull align 16 dereferenceable(40) %1) #0 {
top:
  %2 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %2, i64 0, i32 1
  %arraylen = load i64, i64* %arraylen_ptr, align 8
  %.not = icmp eq i64 %arraylen, 0
  br i1 %.not, label %L41, label %L13.lr.ph

L13.lr.ph:                                        ; preds = %top
  %3 = bitcast {}* %0 to float**
  %arrayptr11 = load float*, float** %3, align 8
  %4 = bitcast {}* %1 to float**
  %arrayptr312 = load float*, float** %4, align 8
  br label %L13

L13:                                              ; preds = %L13, %L13.lr.ph
  %value_phi115 = phi i64 [ 0, %L13.lr.ph ], [ %14, %L13 ]
  %value_phi14 = phi float [ 0.000000e+00, %L13.lr.ph ], [ %13, %L13 ]
  %5 = getelementptr inbounds float, float* %arrayptr11, i64 %value_phi115
  %arrayref = load float, float* %5, align 4
  %6 = getelementptr inbounds float, float* %arrayptr312, i64 %value_phi115
  %arrayref4 = load float, float* %6, align 4
  %7 = fsub float %arrayref, %arrayref4
  %8 = call float @llvm.fabs.f32(float %7)
  %9 = fsub float %value_phi14, %8
  %bitcast_coercion = bitcast float %9 to i32
  %10 = icmp slt i32 %bitcast_coercion, 0
  %11 = select i1 %10, float %8, float %value_phi14
  %12 = fcmp ord float %value_phi14, %7
  %13 = select i1 %12, float %11, float %9
  %14 = add nuw nsw i64 %value_phi115, 1
  %exitcond.not = icmp eq i64 %14, %arraylen
  br i1 %exitcond.not, label %L41, label %L13

L41:                                              ; preds = %L13, %top
  %value_phi7 = phi float [ 0.000000e+00, %top ], [ %13, %L13 ]
  ret float %value_phi7
}
