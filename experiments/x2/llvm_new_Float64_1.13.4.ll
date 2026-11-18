; Function Signature: norm_diff(Array{Float64, 1}, Array{Float64, 1}, Float64)
define double @julia_norm_diff_1232(ptr noundef nonnull align 8 dereferenceable(24) %"A::Array", ptr noundef nonnull align 8 dereferenceable(24) %"B::Array", double %"p::Float64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #16
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %"A::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"A::Array", i64 16
  %"A::Array.size_ptr.copyload" = load i64, ptr %"A::Array.size_ptr", align 8
  %"B::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"B::Array", i64 16
  %"B::Array.size_ptr.copyload" = load i64, ptr %"B::Array.size_ptr", align 8
  %.not.not = icmp eq i64 %"A::Array.size_ptr.copyload", %"B::Array.size_ptr.copyload"
  br i1 %.not.not, label %L19, label %L116

L19:                                              ; preds = %top
  %0 = fcmp une double %"p::Float64", 2.000000e+00
  br i1 %0, label %L26, label %L24

common.ret:                                       ; preds = %L58, %vec.epilog.middle.block, %middle.block, %L49, %L24
  %common.ret.op = phi double [ %1, %L24 ], [ 0.000000e+00, %L49 ], [ %25, %middle.block ], [ %31, %vec.epilog.middle.block ], [ %36, %L58 ]
  %frame.prev96 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev96, ptr %tls_pgcstack, align 8
  ret double %common.ret.op

L24:                                              ; preds = %L19
  %1 = call double @j__norm_diff2_1235(ptr nonnull %"A::Array", ptr nonnull %"B::Array")
  br label %common.ret

L26:                                              ; preds = %L19
  %2 = fcmp une double %"p::Float64", 0x7FF0000000000000
  br i1 %2, label %L113, label %L49

L49:                                              ; preds = %L26
  %3 = icmp slt i64 %"A::Array.size_ptr.copyload", 1
  br i1 %3, label %common.ret, label %iter.check

iter.check:                                       ; preds = %L49
  %memoryref_data = load ptr, ptr %"A::Array", align 8
  %memoryref_data20 = load ptr, ptr %"B::Array", align 8
  %min.iters.check = icmp samesign ult i64 %"A::Array.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L58, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check47 = icmp samesign ult i64 %"A::Array.size_ptr.copyload", 16
  br i1 %min.iters.check47, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"A::Array.size_ptr.copyload", 12
  %n.vec = and i64 %"A::Array.size_ptr.copyload", 9223372036854775792
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %20, %vector.body ]
  %vec.phi48 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %21, %vector.body ]
  %vec.phi49 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %22, %vector.body ]
  %vec.phi50 = phi <4 x double> [ zeroinitializer, %vector.ph ], [ %23, %vector.body ]
  %.reass = shl i64 %index, 3
  %4 = getelementptr inbounds i8, ptr %memoryref_data, i64 %.reass
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 32
  %6 = getelementptr inbounds nuw i8, ptr %4, i64 64
  %7 = getelementptr inbounds nuw i8, ptr %4, i64 96
  %wide.load = load <4 x double>, ptr %4, align 8
  %wide.load51 = load <4 x double>, ptr %5, align 8
  %wide.load52 = load <4 x double>, ptr %6, align 8
  %wide.load53 = load <4 x double>, ptr %7, align 8
  %8 = getelementptr inbounds i8, ptr %memoryref_data20, i64 %.reass
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 32
  %10 = getelementptr inbounds nuw i8, ptr %8, i64 64
  %11 = getelementptr inbounds nuw i8, ptr %8, i64 96
  %wide.load54 = load <4 x double>, ptr %8, align 8
  %wide.load55 = load <4 x double>, ptr %9, align 8
  %wide.load56 = load <4 x double>, ptr %10, align 8
  %wide.load57 = load <4 x double>, ptr %11, align 8
  %12 = fsub <4 x double> %wide.load, %wide.load54
  %13 = fsub <4 x double> %wide.load51, %wide.load55
  %14 = fsub <4 x double> %wide.load52, %wide.load56
  %15 = fsub <4 x double> %wide.load53, %wide.load57
  %16 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %12)
  %17 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %13)
  %18 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %14)
  %19 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %15)
  %20 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi, <4 x double> %16)
  %21 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi48, <4 x double> %17)
  %22 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi49, <4 x double> %18)
  %23 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi50, <4 x double> %19)
  %index.next = add nuw i64 %index, 16
  %24 = icmp eq i64 %index.next, %n.vec
  br i1 %24, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %rdx.minmax = call <4 x double> @llvm.maximum.v4f64(<4 x double> %20, <4 x double> %21)
  %rdx.minmax58 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %rdx.minmax, <4 x double> %22)
  %rdx.minmax59 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %rdx.minmax58, <4 x double> %23)
  %25 = call double @llvm.vector.reduce.fmaximum.v4f64(<4 x double> %rdx.minmax59)
  %cmp.n = icmp eq i64 %"A::Array.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %common.ret, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %ind.end = or disjoint i64 %n.vec, 1
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L58, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi double [ %25, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec61 = and i64 %"A::Array.size_ptr.copyload", 9223372036854775804
  %26 = or disjoint i64 %n.vec61, 1
  %broadcast.splatinsert = insertelement <4 x double> poison, double %bc.merge.rdx, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index62 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next66, %vec.epilog.vector.body ]
  %vec.phi63 = phi <4 x double> [ %broadcast.splat, %vec.epilog.ph ], [ %29, %vec.epilog.vector.body ]
  %.reass74 = shl i64 %index62, 3
  %gep = getelementptr i8, ptr %memoryref_data, i64 %.reass74
  %wide.load64 = load <4 x double>, ptr %gep, align 8
  %gep76 = getelementptr i8, ptr %memoryref_data20, i64 %.reass74
  %wide.load65 = load <4 x double>, ptr %gep76, align 8
  %27 = fsub <4 x double> %wide.load64, %wide.load65
  %28 = call <4 x double> @llvm.fabs.v4f64(<4 x double> %27)
  %29 = call <4 x double> @llvm.maximum.v4f64(<4 x double> %vec.phi63, <4 x double> %28)
  %index.next66 = add nuw i64 %index62, 4
  %30 = icmp eq i64 %index.next66, %n.vec61
  br i1 %30, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %31 = call double @llvm.vector.reduce.fmaximum.v4f64(<4 x double> %29)
  %cmp.n67 = icmp eq i64 %"A::Array.size_ptr.copyload", %n.vec61
  br i1 %cmp.n67, label %common.ret, label %L58

L58:                                              ; preds = %L58, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi11 = phi i64 [ %37, %L58 ], [ %26, %vec.epilog.middle.block ], [ 1, %iter.check ], [ %ind.end, %vec.epilog.iter.check ]
  %value_phi13 = phi double [ %36, %L58 ], [ %31, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %25, %vec.epilog.iter.check ]
  %memoryref_offset = shl i64 %value_phi11, 3
  %memoryref_byteoffset = add i64 %memoryref_offset, -8
  %memoryref_data16 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %32 = load double, ptr %memoryref_data16, align 8
  %memoryref_data28 = getelementptr inbounds i8, ptr %memoryref_data20, i64 %memoryref_byteoffset
  %33 = load double, ptr %memoryref_data28, align 8
  %34 = fsub double %32, %33
  %35 = call double @llvm.fabs.f64(double %34)
  %36 = call double @llvm.maximum.f64(double %value_phi13, double %35)
  %.not = icmp eq i64 %value_phi11, %"A::Array.size_ptr.copyload"
  %37 = add nuw i64 %value_phi11, 1
  br i1 %.not, label %common.ret, label %L58

L113:                                             ; preds = %L26
  %38 = call [1 x ptr] @j_ArgumentError_1239(ptr nonnull @"jl_global#1240.jit")
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  %39 = extractvalue [1 x ptr] %38, 0
  store ptr %39, ptr %gc_slot_addr_0, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::ArgumentError" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 128967423084208) #11
  %"box::ArgumentError.tag_addr" = getelementptr inbounds i8, ptr %"box::ArgumentError", i64 -8
  store atomic i64 128967423084208, ptr %"box::ArgumentError.tag_addr" unordered, align 8
  store ptr %39, ptr %"box::ArgumentError", align 8
  store ptr null, ptr %gc_slot_addr_0, align 8
  call void @ijl_throw(ptr nonnull %"box::ArgumentError")
  unreachable

L116:                                             ; preds = %top
  %40 = call [1 x ptr] @j_DimensionMismatch_1242(ptr nonnull @"jl_global#1243.jit")
  %gc_slot_addr_083 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  %41 = extractvalue [1 x ptr] %40, 0
  store ptr %41, ptr %gc_slot_addr_083, align 8
  %ptls_field93 = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load94 = load ptr, ptr %ptls_field93, align 8
  %"box::DimensionMismatch" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load94, i32 360, i32 16, i64 128967350944432) #11
  %"box::DimensionMismatch.tag_addr" = getelementptr inbounds i8, ptr %"box::DimensionMismatch", i64 -8
  store atomic i64 128967350944432, ptr %"box::DimensionMismatch.tag_addr" unordered, align 8
  store ptr %41, ptr %"box::DimensionMismatch", align 8
  store ptr null, ptr %gc_slot_addr_083, align 8
  call void @ijl_throw(ptr nonnull %"box::DimensionMismatch")
  unreachable
}
