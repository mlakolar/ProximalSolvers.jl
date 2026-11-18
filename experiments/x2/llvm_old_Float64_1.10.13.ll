define double @julia__maxabs_diff_707({}* noundef nonnull align 16 dereferenceable(40) %0, {}* noundef nonnull align 16 dereferenceable(40) %1) #0 {
top:
  %2 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %2, i64 0, i32 1
  %arraylen = load i64, i64* %arraylen_ptr, align 8
  %.not = icmp eq i64 %arraylen, 0
  br i1 %.not, label %L40, label %L13.lr.ph

L13.lr.ph:                                        ; preds = %top
  %3 = bitcast {}* %0 to double**
  %arrayptr11 = load double*, double** %3, align 8
  %4 = bitcast {}* %1 to double**
  %arrayptr312 = load double*, double** %4, align 8
  br label %L13

L13:                                              ; preds = %L13, %L13.lr.ph
  %value_phi115 = phi i64 [ 0, %L13.lr.ph ], [ %14, %L13 ]
  %value_phi14 = phi double [ 0.000000e+00, %L13.lr.ph ], [ %13, %L13 ]
  %5 = getelementptr inbounds double, double* %arrayptr11, i64 %value_phi115
  %arrayref = load double, double* %5, align 8
  %6 = getelementptr inbounds double, double* %arrayptr312, i64 %value_phi115
  %arrayref4 = load double, double* %6, align 8
  %7 = fsub double %arrayref, %arrayref4
  %8 = call double @llvm.fabs.f64(double %7)
  %9 = fsub double %value_phi14, %8
  %bitcast_coercion = bitcast double %9 to i64
  %10 = icmp slt i64 %bitcast_coercion, 0
  %11 = select i1 %10, double %8, double %value_phi14
  %12 = fcmp ord double %value_phi14, %7
  %13 = select i1 %12, double %11, double %9
  %14 = add nuw nsw i64 %value_phi115, 1
  %exitcond.not = icmp eq i64 %14, %arraylen
  br i1 %exitcond.not, label %L40, label %L13

L40:                                              ; preds = %L13, %top
  %value_phi7 = phi double [ 0.000000e+00, %top ], [ %13, %L13 ]
  ret double %value_phi7
}
