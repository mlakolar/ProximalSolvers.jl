; Function Signature: _maxabs_diff(Array{Float64, 1}, Array{Float64, 1})
define double @julia__maxabs_diff_1215(ptr noundef nonnull align 8 dereferenceable(24) %"x::Array", ptr noundef nonnull align 8 dereferenceable(24) %"y::Array") local_unnamed_addr #0 {
top:
  %"x::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"x::Array", i64 16
  %"x::Array.size_ptr.copyload" = load i64, ptr %"x::Array.size_ptr", align 8
  %0 = icmp slt i64 %"x::Array.size_ptr.copyload", 1
  br i1 %0, label %L67, label %iter.check

iter.check:                                       ; preds = %top
  %memoryref_data = load ptr, ptr %"x::Array", align 8
  %memoryref_data8 = load ptr, ptr %"y::Array", align 8
  %min.iters.check = icmp samesign ult i64 %"x::Array.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L12, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check26 = icmp samesign ult i64 %"x::Array.size_ptr.copyload", 16
  br i1 %min.iters.check26, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"x::Array.size_ptr.copyload", 12
  %n.vec = and i64 %"x::Array.size_ptr.copyload", 9223372036854775792
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %18, %vector.body ]
  %vec.phi27 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %19, %vector.body ]
  %vec.phi28 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %20, %vector.body ]
  %vec.phi29 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %21, %vector.body ]
  %1 = shl i64 %index, 3
  %2 = getelementptr inbounds i8, ptr %memoryref_data, i64 %1
  %3 = getelementptr inbounds nuw i8, ptr %2, i64 32
  %4 = getelementptr inbounds nuw i8, ptr %2, i64 64
  %5 = getelementptr inbounds nuw i8, ptr %2, i64 96
  %wide.load = load <4 x double>, ptr %2, align 8
  %wide.load30 = load <4 x double>, ptr %3, align 8
  %wide.load31 = load <4 x double>, ptr %4, align 8
  %wide.load32 = load <4 x double>, ptr %5, align 8
  %6 = getelementptr inbounds i8, ptr %memoryref_data8, i64 %1
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 32
  %8 = getelementptr inbounds nuw i8, ptr %6, i64 64
  %9 = getelementptr inbounds nuw i8, ptr %6, i64 96
  %wide.load33 = load <4 x double>, ptr %6, align 8
  %wide.load34 = load <4 x double>, ptr %7, align 8
  %wide.load35 = load <4 x double>, ptr %8, align 8
  %wide.load36 = load <4 x double>, ptr %9, align 8
  %10 = fsub <4 x double> %wide.load, %wide.load33
  %11 = fsub <4 x double> %wide.load30, %wide.load34
  %12 = fsub <4 x double> %wide.load31, %wide.load35
  %13 = fsub <4 x double> %wide.load32, %wide.load36
  %14 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %10)
  %15 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %11)
  %16 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %12)
  %17 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %13)
  %18 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi, <4 x double> %14)
  %19 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi27, <4 x double> %15)
  %20 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi28, <4 x double> %16)
  %21 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi29, <4 x double> %17)
  %index.next = add nuw i64 %index, 16
  %22 = icmp eq i64 %index.next, %n.vec
  br i1 %22, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %rdx.minmax = call <4 x double> @llvm.maximum.v4f64(<4 x double> %18, <4 x double> %19)
  %rdx.minmax37 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %rdx.minmax, <4 x double> %20)
  %rdx.minmax38 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %rdx.minmax37, <4 x double> %21)
  %23 = call double @llvm.vector.reduce.fmaximum.v4f64(<4 x double> %rdx.minmax38)
  %cmp.n = icmp eq i64 %"x::Array.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L67, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L12, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi double [ %23, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec40 = and i64 %"x::Array.size_ptr.copyload", 9223372036854775804
  %broadcast.splatinsert = insertelement <4 x double> poison, double %bc.merge.rdx, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index41 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next45, %vec.epilog.vector.body ]
  %vec.phi42 = phi <4 x double> [ %broadcast.splat, %vec.epilog.ph ], [ %27, %vec.epilog.vector.body ]
  %24 = shl i64 %index41, 3
  %gep = getelementptr i8, ptr %memoryref_data, i64 %24
  %wide.load43 = load <4 x double>, ptr %gep, align 8
  %gep54 = getelementptr i8, ptr %memoryref_data8, i64 %24
  %wide.load44 = load <4 x double>, ptr %gep54, align 8
  %25 = fsub <4 x double> %wide.load43, %wide.load44
  %26 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %25)
  %27 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi42, <4 x double> %26)
  %index.next45 = add nuw i64 %index41, 4
  %28 = icmp eq i64 %index.next45, %n.vec40
  br i1 %28, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %29 = call double @llvm.vector.reduce.fmaximum.v4f64(<4 x double> %27)
  %cmp.n46 = icmp eq i64 %"x::Array.size_ptr.copyload", %n.vec40
  br i1 %cmp.n46, label %L67, label %L12

L12:                                              ; preds = %L12, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi125 = phi i64 [ %30, %L12 ], [ %n.vec40, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi24 = phi double [ %35, %L12 ], [ %29, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %23, %vec.epilog.iter.check ]
  %30 = add nuw nsw i64 %value_phi125, 1
  %memoryref_byteoffset = shl i64 %value_phi125, 3
  %memoryref_data6 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %31 = load double, ptr %memoryref_data6, align 8
  %memoryref_data16 = getelementptr inbounds i8, ptr %memoryref_data8, i64 %memoryref_byteoffset
  %32 = load double, ptr %memoryref_data16, align 8
  %33 = fsub double %31, %32
  %34 = call double @llvm.fabs.f64(double %33)
  %35 = call double @llvm.maximum.f64(double %value_phi24, double %34)
  %exitcond.not = icmp eq i64 %30, %"x::Array.size_ptr.copyload"
  br i1 %exitcond.not, label %L67, label %L12

L67:                                              ; preds = %L12, %vec.epilog.middle.block, %middle.block, %top
  %value_phi21 = phi double [ 0.000000e+00, %top ], [ %23, %middle.block ], [ %29, %vec.epilog.middle.block ], [ %35, %L12 ]
  ret double %value_phi21
}
