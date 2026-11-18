; Function Signature: norm_diff(Array{Float32, 1}, Array{Float32, 1}, Float64)
define float @julia_norm_diff_964(ptr noundef nonnull align 8 dereferenceable(24) %"A::Array", ptr noundef nonnull align 8 dereferenceable(24) %"B::Array", double %"p::Float64") local_unnamed_addr #0 {
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
  %common.ret.op = phi float [ %1, %L24 ], [ 0.000000e+00, %L49 ], [ %25, %middle.block ], [ %31, %vec.epilog.middle.block ], [ %36, %L58 ]
  %frame.prev96 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev96, ptr %tls_pgcstack, align 8
  ret float %common.ret.op

L24:                                              ; preds = %L19
  %1 = call float @j__norm_diff2_966(ptr nonnull %"A::Array", ptr nonnull %"B::Array")
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
  %min.iters.check47 = icmp samesign ult i64 %"A::Array.size_ptr.copyload", 32
  br i1 %min.iters.check47, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"A::Array.size_ptr.copyload", 28
  %n.vec = and i64 %"A::Array.size_ptr.copyload", 9223372036854775776
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ zeroinitializer, %vector.ph ], [ %20, %vector.body ]
  %vec.phi48 = phi <8 x float> [ zeroinitializer, %vector.ph ], [ %21, %vector.body ]
  %vec.phi49 = phi <8 x float> [ zeroinitializer, %vector.ph ], [ %22, %vector.body ]
  %vec.phi50 = phi <8 x float> [ zeroinitializer, %vector.ph ], [ %23, %vector.body ]
  %.reass = shl i64 %index, 2
  %4 = getelementptr inbounds i8, ptr %memoryref_data, i64 %.reass
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 32
  %6 = getelementptr inbounds nuw i8, ptr %4, i64 64
  %7 = getelementptr inbounds nuw i8, ptr %4, i64 96
  %wide.load = load <8 x float>, ptr %4, align 4
  %wide.load51 = load <8 x float>, ptr %5, align 4
  %wide.load52 = load <8 x float>, ptr %6, align 4
  %wide.load53 = load <8 x float>, ptr %7, align 4
  %8 = getelementptr inbounds i8, ptr %memoryref_data20, i64 %.reass
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 32
  %10 = getelementptr inbounds nuw i8, ptr %8, i64 64
  %11 = getelementptr inbounds nuw i8, ptr %8, i64 96
  %wide.load54 = load <8 x float>, ptr %8, align 4
  %wide.load55 = load <8 x float>, ptr %9, align 4
  %wide.load56 = load <8 x float>, ptr %10, align 4
  %wide.load57 = load <8 x float>, ptr %11, align 4
  %12 = fsub <8 x float> %wide.load, %wide.load54
  %13 = fsub <8 x float> %wide.load51, %wide.load55
  %14 = fsub <8 x float> %wide.load52, %wide.load56
  %15 = fsub <8 x float> %wide.load53, %wide.load57
  %16 = call <8 x float> @llvm.fabs.v8f32(<8 x float> %12)
  %17 = call <8 x float> @llvm.fabs.v8f32(<8 x float> %13)
  %18 = call <8 x float> @llvm.fabs.v8f32(<8 x float> %14)
  %19 = call <8 x float> @llvm.fabs.v8f32(<8 x float> %15)
  %20 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %vec.phi, <8 x float> %16)
  %21 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %vec.phi48, <8 x float> %17)
  %22 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %vec.phi49, <8 x float> %18)
  %23 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %vec.phi50, <8 x float> %19)
  %index.next = add nuw i64 %index, 32
  %24 = icmp eq i64 %index.next, %n.vec
  br i1 %24, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %rdx.minmax = call <8 x float> @llvm.maximum.v8f32(<8 x float> %20, <8 x float> %21)
  %rdx.minmax58 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %rdx.minmax, <8 x float> %22)
  %rdx.minmax59 = call <8 x float> @llvm.maximum.v8f32(<8 x float> %rdx.minmax58, <8 x float> %23)
  %25 = call float @llvm.vector.reduce.fmaximum.v8f32(<8 x float> %rdx.minmax59)
  %cmp.n = icmp eq i64 %"A::Array.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %common.ret, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %ind.end = or disjoint i64 %n.vec, 1
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L58, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi float [ %25, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec61 = and i64 %"A::Array.size_ptr.copyload", 9223372036854775804
  %26 = or disjoint i64 %n.vec61, 1
  %broadcast.splatinsert = insertelement <4 x float> poison, float %bc.merge.rdx, i64 0
  %broadcast.splat = shufflevector <4 x float> %broadcast.splatinsert, <4 x float> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index62 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next66, %vec.epilog.vector.body ]
  %vec.phi63 = phi <4 x float> [ %broadcast.splat, %vec.epilog.ph ], [ %29, %vec.epilog.vector.body ]
  %.reass74 = shl i64 %index62, 2
  %gep = getelementptr i8, ptr %memoryref_data, i64 %.reass74
  %wide.load64 = load <4 x float>, ptr %gep, align 4
  %gep76 = getelementptr i8, ptr %memoryref_data20, i64 %.reass74
  %wide.load65 = load <4 x float>, ptr %gep76, align 4
  %27 = fsub <4 x float> %wide.load64, %wide.load65
  %28 = call <4 x float> @llvm.fabs.v4f32(<4 x float> %27)
  %29 = call <4 x float> @llvm.maximum.v4f32(<4 x float> %vec.phi63, <4 x float> %28)
  %index.next66 = add nuw i64 %index62, 4
  %30 = icmp eq i64 %index.next66, %n.vec61
  br i1 %30, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %31 = call float @llvm.vector.reduce.fmaximum.v4f32(<4 x float> %29)
  %cmp.n67 = icmp eq i64 %"A::Array.size_ptr.copyload", %n.vec61
  br i1 %cmp.n67, label %common.ret, label %L58

L58:                                              ; preds = %L58, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi11 = phi i64 [ %37, %L58 ], [ %26, %vec.epilog.middle.block ], [ 1, %iter.check ], [ %ind.end, %vec.epilog.iter.check ]
  %value_phi13 = phi float [ %36, %L58 ], [ %31, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %25, %vec.epilog.iter.check ]
  %memoryref_offset = shl i64 %value_phi11, 2
  %memoryref_byteoffset = add i64 %memoryref_offset, -4
  %memoryref_data16 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %32 = load float, ptr %memoryref_data16, align 4
  %memoryref_data28 = getelementptr inbounds i8, ptr %memoryref_data20, i64 %memoryref_byteoffset
  %33 = load float, ptr %memoryref_data28, align 4
  %34 = fsub float %32, %33
  %35 = call float @llvm.fabs.f32(float %34)
  %36 = call float @llvm.maximum.f32(float %value_phi13, float %35)
  %.not = icmp eq i64 %value_phi11, %"A::Array.size_ptr.copyload"
  %37 = add nuw i64 %value_phi11, 1
  br i1 %.not, label %common.ret, label %L58

L113:                                             ; preds = %L26
  %38 = call [1 x ptr] @j_ArgumentError_970(ptr nonnull @"jl_global#971.jit")
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  %39 = extractvalue [1 x ptr] %38, 0
  store ptr %39, ptr %gc_slot_addr_0, align 8
  %ptls_field = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load = load ptr, ptr %ptls_field, align 8
  %"box::ArgumentError" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load, i32 360, i32 16, i64 128967423084208) #12
  %"box::ArgumentError.tag_addr" = getelementptr inbounds i8, ptr %"box::ArgumentError", i64 -8
  store atomic i64 128967423084208, ptr %"box::ArgumentError.tag_addr" unordered, align 8
  store ptr %39, ptr %"box::ArgumentError", align 8
  store ptr null, ptr %gc_slot_addr_0, align 8
  call void @ijl_throw(ptr nonnull %"box::ArgumentError")
  unreachable

L116:                                             ; preds = %top
  %40 = call [1 x ptr] @j_DimensionMismatch_973(ptr nonnull @"jl_global#974.jit")
  %gc_slot_addr_083 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  %41 = extractvalue [1 x ptr] %40, 0
  store ptr %41, ptr %gc_slot_addr_083, align 8
  %ptls_field93 = getelementptr inbounds nuw i8, ptr %tls_pgcstack, i64 16
  %ptls_load94 = load ptr, ptr %ptls_field93, align 8
  %"box::DimensionMismatch" = call noalias nonnull align 8 dereferenceable(16) ptr @ijl_gc_small_alloc(ptr %ptls_load94, i32 360, i32 16, i64 128967350944432) #12
  %"box::DimensionMismatch.tag_addr" = getelementptr inbounds i8, ptr %"box::DimensionMismatch", i64 -8
  store atomic i64 128967350944432, ptr %"box::DimensionMismatch.tag_addr" unordered, align 8
  store ptr %41, ptr %"box::DimensionMismatch", align 8
  store ptr null, ptr %gc_slot_addr_083, align 8
  call void @ijl_throw(ptr nonnull %"box::DimensionMismatch")
  unreachable
}
