; Function Signature: pass(typeof(M_x1d.ProximalSolvers._column_dot_rsqr), typeof(M_x1d.ProximalSolvers._sqrt_minimizer), M_x1d.ProximalSolvers.SqrtLSModel{Float32, M_x1d.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
; Function Attrs: noinline
define float @julia_pass_3548(ptr noundef nonnull align 8 dereferenceable(72) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %"new::Tuple89" = alloca { [1 x [1 x i64]], i64 }, align 8
  %"new::Tuple153" = alloca [1 x i64], align 8
  %"new::Tuple209" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #14
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %".reps::Int64" = call i64 @llvm.smax.i64(i64 %"reps::Int64", i64 0)
  %0 = icmp slt i64 %"reps::Int64", 1
  br i1 %0, label %L533, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %"m::SqrtLSModel.ls" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"xv::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"xv::Array", i64 16
  %"m::SqrtLSModel.ls.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 24
  %"m::SqrtLSModel.ls.a_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 32
  %"m::SqrtLSModel.gt_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel", i64 8
  %1 = load i64, ptr %"xv::Array.size_ptr", align 8
  %2 = icmp slt i64 %1, 1
  br i1 %2, label %L533, label %L17

L17thread-pre-split:                              ; preds = %L522
  %3 = add nuw i64 %value_phi3, 1
  %"xv::Array.size_ptr.copyload.pr" = load i64, ptr %"xv::Array.size_ptr", align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %"xv::Array.size_ptr.copyload" = phi i64 [ %"xv::Array.size_ptr.copyload.pr", %L17thread-pre-split ], [ %1, %L17.preheader ]
  %value_phi3 = phi i64 [ %3, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi83, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %4 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %4, label %L522, label %L31

L31:                                              ; preds = %L510, %L17
  %value_phi8 = phi float [ %188, %L510 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %189, %L510 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %5 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %5, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple209", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_0, align 8
  call void @j_throw_boundserror_3550(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple209") #15
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %5, 2
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %6 = load float, ptr %memoryref_data11, align 4
  %7 = fcmp ord float %6, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr155" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr155.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr155", align 8
  %8 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 1
  br i1 %7, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %8, label %L299, label %iter.check618

iter.check618:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %9 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %5
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check616 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 4
  br i1 %min.iters.check616, label %L71, label %vector.main.loop.iter.check620

vector.main.loop.iter.check620:                   ; preds = %iter.check618
  %min.iters.check619 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 16
  br i1 %min.iters.check619, label %vec.epilog.ph647, label %vector.ph621

vector.ph621:                                     ; preds = %vector.main.loop.iter.check620
  %n.mod.vf622 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 12
  %n.vec623 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775792
  br label %vector.body624

vector.body624:                                   ; preds = %vector.body624, %vector.ph621
  %index625 = phi i64 [ 0, %vector.ph621 ], [ %index.next636, %vector.body624 ]
  %vec.phi626 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph621 ], [ %18, %vector.body624 ]
  %vec.phi627 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph621 ], [ %19, %vector.body624 ]
  %vec.phi628 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph621 ], [ %22, %vector.body624 ]
  %vec.phi629 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph621 ], [ %23, %vector.body624 ]
  %vec.phi630 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph621 ], [ %26, %vector.body624 ]
  %vec.phi631 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph621 ], [ %27, %vector.body624 ]
  %.reass = add i64 %index625, %9
  %10 = shl i64 %.reass, 2
  %11 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %10
  %12 = getelementptr inbounds nuw i8, ptr %11, i64 32
  %wide.load632 = load <8 x float>, ptr %11, align 4
  %wide.load633 = load <8 x float>, ptr %12, align 4
  %13 = shl i64 %index625, 2
  %14 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %13
  %15 = getelementptr inbounds nuw i8, ptr %14, i64 32
  %wide.load634 = load <8 x float>, ptr %14, align 4
  %wide.load635 = load <8 x float>, ptr %15, align 4
  %16 = fmul contract <8 x float> %wide.load632, %wide.load632
  %17 = fmul contract <8 x float> %wide.load633, %wide.load633
  %18 = fadd reassoc contract <8 x float> %vec.phi626, %16
  %19 = fadd reassoc contract <8 x float> %vec.phi627, %17
  %20 = fmul contract <8 x float> %wide.load632, %wide.load634
  %21 = fmul contract <8 x float> %wide.load633, %wide.load635
  %22 = fadd reassoc contract <8 x float> %vec.phi628, %20
  %23 = fadd reassoc contract <8 x float> %vec.phi629, %21
  %24 = fmul contract <8 x float> %wide.load634, %wide.load634
  %25 = fmul contract <8 x float> %wide.load635, %wide.load635
  %26 = fadd reassoc contract <8 x float> %vec.phi630, %24
  %27 = fadd reassoc contract <8 x float> %vec.phi631, %25
  %index.next636 = add nuw i64 %index625, 16
  %28 = icmp eq i64 %index.next636, %n.vec623
  br i1 %28, label %middle.block615, label %vector.body624

middle.block615:                                  ; preds = %vector.body624
  %bin.rdx637 = fadd reassoc contract <8 x float> %19, %18
  %29 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx637)
  %bin.rdx638 = fadd reassoc contract <8 x float> %23, %22
  %30 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx638)
  %bin.rdx639 = fadd reassoc contract <8 x float> %27, %26
  %31 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx639)
  %cmp.n640 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec623
  br i1 %cmp.n640, label %L299, label %vec.epilog.iter.check648

vec.epilog.iter.check648:                         ; preds = %middle.block615
  %min.epilog.iters.check650 = icmp eq i64 %n.mod.vf622, 0
  br i1 %min.epilog.iters.check650, label %L71, label %vec.epilog.ph647

vec.epilog.ph647:                                 ; preds = %vec.epilog.iter.check648, %vector.main.loop.iter.check620
  %vec.epilog.resume.val641 = phi i64 [ %n.vec623, %vec.epilog.iter.check648 ], [ 0, %vector.main.loop.iter.check620 ]
  %bc.merge.rdx642 = phi float [ %29, %vec.epilog.iter.check648 ], [ 0.000000e+00, %vector.main.loop.iter.check620 ]
  %bc.merge.rdx643 = phi float [ %30, %vec.epilog.iter.check648 ], [ 0.000000e+00, %vector.main.loop.iter.check620 ]
  %bc.merge.rdx644 = phi float [ %31, %vec.epilog.iter.check648 ], [ 0.000000e+00, %vector.main.loop.iter.check620 ]
  %n.vec652 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775804
  %32 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx642, i64 0
  %33 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx643, i64 0
  %34 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx644, i64 0
  br label %vec.epilog.vector.body653

vec.epilog.vector.body653:                        ; preds = %vec.epilog.vector.body653, %vec.epilog.ph647
  %index654 = phi i64 [ %vec.epilog.resume.val641, %vec.epilog.ph647 ], [ %index.next660, %vec.epilog.vector.body653 ]
  %vec.phi655 = phi <4 x float> [ %32, %vec.epilog.ph647 ], [ %38, %vec.epilog.vector.body653 ]
  %vec.phi656 = phi <4 x float> [ %33, %vec.epilog.ph647 ], [ %40, %vec.epilog.vector.body653 ]
  %vec.phi657 = phi <4 x float> [ %34, %vec.epilog.ph647 ], [ %42, %vec.epilog.vector.body653 ]
  %.reass699 = add i64 %index654, %9
  %35 = shl i64 %.reass699, 2
  %gep = getelementptr i8, ptr %memoryref_data30, i64 %35
  %wide.load658 = load <4 x float>, ptr %gep, align 4
  %36 = shl i64 %index654, 2
  %gep701 = getelementptr i8, ptr %memoryref_data42, i64 %36
  %wide.load659 = load <4 x float>, ptr %gep701, align 4
  %37 = fmul contract <4 x float> %wide.load658, %wide.load658
  %38 = fadd reassoc contract <4 x float> %vec.phi655, %37
  %39 = fmul contract <4 x float> %wide.load658, %wide.load659
  %40 = fadd reassoc contract <4 x float> %vec.phi656, %39
  %41 = fmul contract <4 x float> %wide.load659, %wide.load659
  %42 = fadd reassoc contract <4 x float> %vec.phi657, %41
  %index.next660 = add nuw i64 %index654, 4
  %43 = icmp eq i64 %index.next660, %n.vec652
  br i1 %43, label %vec.epilog.middle.block645, label %vec.epilog.vector.body653

vec.epilog.middle.block645:                       ; preds = %vec.epilog.vector.body653
  %44 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %38)
  %45 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %40)
  %46 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %42)
  %cmp.n661 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec652
  br i1 %cmp.n661, label %L299, label %L71

L71:                                              ; preds = %L71, %vec.epilog.middle.block645, %vec.epilog.iter.check648, %iter.check618
  %value_phi15272 = phi float [ %51, %L71 ], [ %44, %vec.epilog.middle.block645 ], [ 0.000000e+00, %iter.check618 ], [ %29, %vec.epilog.iter.check648 ]
  %value_phi14271 = phi i64 [ %47, %L71 ], [ %n.vec652, %vec.epilog.middle.block645 ], [ 0, %iter.check618 ], [ %n.vec623, %vec.epilog.iter.check648 ]
  %value_phi13270 = phi float [ %53, %L71 ], [ %45, %vec.epilog.middle.block645 ], [ 0.000000e+00, %iter.check618 ], [ %30, %vec.epilog.iter.check648 ]
  %value_phi12269 = phi float [ %55, %L71 ], [ %46, %vec.epilog.middle.block645 ], [ 0.000000e+00, %iter.check618 ], [ %31, %vec.epilog.iter.check648 ]
  %47 = add nuw nsw i64 %value_phi14271, 1
  %memoryref_offset32 = add i64 %9, %value_phi14271
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 2
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %48 = load float, ptr %memoryref_data38, align 4
  %memoryref_byteoffset45 = shl i64 %value_phi14271, 2
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %49 = load float, ptr %memoryref_data50, align 4
  %50 = fmul contract float %48, %48
  %51 = fadd reassoc contract float %value_phi15272, %50
  %52 = fmul contract float %48, %49
  %53 = fadd reassoc contract float %value_phi13270, %52
  %54 = fmul contract float %49, %49
  %55 = fadd reassoc contract float %value_phi12269, %54
  %exitcond.not = icmp eq i64 %47, %"m::SqrtLSModel.ls.r.size_ptr155.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %8, label %L299, label %iter.check561

iter.check561:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr172" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr172.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr172", align 8
  %56 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr172.copyload", %5
  %memoryref_data179 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data192 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check559 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 4
  br i1 %min.iters.check559, label %L190, label %vector.main.loop.iter.check563

vector.main.loop.iter.check563:                   ; preds = %iter.check561
  %min.iters.check562 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 32
  br i1 %min.iters.check562, label %vec.epilog.ph598, label %vector.ph564

vector.ph564:                                     ; preds = %vector.main.loop.iter.check563
  %n.mod.vf565 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 28
  %n.vec566 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775776
  br label %vector.body567

vector.body567:                                   ; preds = %vector.body567, %vector.ph564
  %index568 = phi i64 [ 0, %vector.ph564 ], [ %index.next585, %vector.body567 ]
  %vec.phi569 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph564 ], [ %71, %vector.body567 ]
  %vec.phi570 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %72, %vector.body567 ]
  %vec.phi571 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %73, %vector.body567 ]
  %vec.phi572 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %74, %vector.body567 ]
  %vec.phi573 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph564 ], [ %79, %vector.body567 ]
  %vec.phi574 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %80, %vector.body567 ]
  %vec.phi575 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %81, %vector.body567 ]
  %vec.phi576 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph564 ], [ %82, %vector.body567 ]
  %.reass703 = add i64 %index568, %56
  %57 = shl i64 %.reass703, 2
  %58 = getelementptr inbounds i8, ptr %memoryref_data179, i64 %57
  %59 = getelementptr inbounds nuw i8, ptr %58, i64 32
  %60 = getelementptr inbounds nuw i8, ptr %58, i64 64
  %61 = getelementptr inbounds nuw i8, ptr %58, i64 96
  %wide.load577 = load <8 x float>, ptr %58, align 4
  %wide.load578 = load <8 x float>, ptr %59, align 4
  %wide.load579 = load <8 x float>, ptr %60, align 4
  %wide.load580 = load <8 x float>, ptr %61, align 4
  %62 = shl i64 %index568, 2
  %63 = getelementptr inbounds i8, ptr %memoryref_data192, i64 %62
  %64 = getelementptr inbounds nuw i8, ptr %63, i64 32
  %65 = getelementptr inbounds nuw i8, ptr %63, i64 64
  %66 = getelementptr inbounds nuw i8, ptr %63, i64 96
  %wide.load581 = load <8 x float>, ptr %63, align 4
  %wide.load582 = load <8 x float>, ptr %64, align 4
  %wide.load583 = load <8 x float>, ptr %65, align 4
  %wide.load584 = load <8 x float>, ptr %66, align 4
  %67 = fmul contract <8 x float> %wide.load577, %wide.load581
  %68 = fmul contract <8 x float> %wide.load578, %wide.load582
  %69 = fmul contract <8 x float> %wide.load579, %wide.load583
  %70 = fmul contract <8 x float> %wide.load580, %wide.load584
  %71 = fadd reassoc contract <8 x float> %vec.phi569, %67
  %72 = fadd reassoc contract <8 x float> %vec.phi570, %68
  %73 = fadd reassoc contract <8 x float> %vec.phi571, %69
  %74 = fadd reassoc contract <8 x float> %vec.phi572, %70
  %75 = fmul contract <8 x float> %wide.load581, %wide.load581
  %76 = fmul contract <8 x float> %wide.load582, %wide.load582
  %77 = fmul contract <8 x float> %wide.load583, %wide.load583
  %78 = fmul contract <8 x float> %wide.load584, %wide.load584
  %79 = fadd reassoc contract <8 x float> %vec.phi573, %75
  %80 = fadd reassoc contract <8 x float> %vec.phi574, %76
  %81 = fadd reassoc contract <8 x float> %vec.phi575, %77
  %82 = fadd reassoc contract <8 x float> %vec.phi576, %78
  %index.next585 = add nuw i64 %index568, 32
  %83 = icmp eq i64 %index.next585, %n.vec566
  br i1 %83, label %middle.block558, label %vector.body567

middle.block558:                                  ; preds = %vector.body567
  %bin.rdx586 = fadd reassoc contract <8 x float> %72, %71
  %bin.rdx587 = fadd reassoc contract <8 x float> %73, %bin.rdx586
  %bin.rdx588 = fadd reassoc contract <8 x float> %74, %bin.rdx587
  %84 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx588)
  %bin.rdx589 = fadd reassoc contract <8 x float> %80, %79
  %bin.rdx590 = fadd reassoc contract <8 x float> %81, %bin.rdx589
  %bin.rdx591 = fadd reassoc contract <8 x float> %82, %bin.rdx590
  %85 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx591)
  %cmp.n592 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec566
  br i1 %cmp.n592, label %L299, label %vec.epilog.iter.check599

vec.epilog.iter.check599:                         ; preds = %middle.block558
  %min.epilog.iters.check601 = icmp eq i64 %n.mod.vf565, 0
  br i1 %min.epilog.iters.check601, label %L190, label %vec.epilog.ph598

vec.epilog.ph598:                                 ; preds = %vec.epilog.iter.check599, %vector.main.loop.iter.check563
  %vec.epilog.resume.val593 = phi i64 [ %n.vec566, %vec.epilog.iter.check599 ], [ 0, %vector.main.loop.iter.check563 ]
  %bc.merge.rdx594 = phi float [ %84, %vec.epilog.iter.check599 ], [ 0.000000e+00, %vector.main.loop.iter.check563 ]
  %bc.merge.rdx595 = phi float [ %85, %vec.epilog.iter.check599 ], [ 0.000000e+00, %vector.main.loop.iter.check563 ]
  %n.vec603 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775804
  %86 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx594, i64 0
  %87 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx595, i64 0
  br label %vec.epilog.vector.body604

vec.epilog.vector.body604:                        ; preds = %vec.epilog.vector.body604, %vec.epilog.ph598
  %index605 = phi i64 [ %vec.epilog.resume.val593, %vec.epilog.ph598 ], [ %index.next610, %vec.epilog.vector.body604 ]
  %vec.phi606 = phi <4 x float> [ %86, %vec.epilog.ph598 ], [ %91, %vec.epilog.vector.body604 ]
  %vec.phi607 = phi <4 x float> [ %87, %vec.epilog.ph598 ], [ %93, %vec.epilog.vector.body604 ]
  %.reass705 = add i64 %index605, %56
  %88 = shl i64 %.reass705, 2
  %gep707 = getelementptr i8, ptr %memoryref_data179, i64 %88
  %wide.load608 = load <4 x float>, ptr %gep707, align 4
  %89 = shl i64 %index605, 2
  %gep709 = getelementptr i8, ptr %memoryref_data192, i64 %89
  %wide.load609 = load <4 x float>, ptr %gep709, align 4
  %90 = fmul contract <4 x float> %wide.load608, %wide.load609
  %91 = fadd reassoc contract <4 x float> %vec.phi606, %90
  %92 = fmul contract <4 x float> %wide.load609, %wide.load609
  %93 = fadd reassoc contract <4 x float> %vec.phi607, %92
  %index.next610 = add nuw i64 %index605, 4
  %94 = icmp eq i64 %index.next610, %n.vec603
  br i1 %94, label %vec.epilog.middle.block596, label %vec.epilog.vector.body604

vec.epilog.middle.block596:                       ; preds = %vec.epilog.vector.body604
  %95 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %91)
  %96 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %93)
  %cmp.n611 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec603
  br i1 %cmp.n611, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block596, %vec.epilog.iter.check599, %iter.check561
  %value_phi160275 = phi i64 [ %97, %L190 ], [ %n.vec603, %vec.epilog.middle.block596 ], [ 0, %iter.check561 ], [ %n.vec566, %vec.epilog.iter.check599 ]
  %value_phi159274 = phi float [ %101, %L190 ], [ %95, %vec.epilog.middle.block596 ], [ 0.000000e+00, %iter.check561 ], [ %84, %vec.epilog.iter.check599 ]
  %value_phi158273 = phi float [ %103, %L190 ], [ %96, %vec.epilog.middle.block596 ], [ 0.000000e+00, %iter.check561 ], [ %85, %vec.epilog.iter.check599 ]
  %97 = add nuw nsw i64 %value_phi160275, 1
  %memoryref_offset181 = add i64 %56, %value_phi160275
  %memoryref_byteoffset182 = shl i64 %memoryref_offset181, 2
  %memoryref_data187 = getelementptr inbounds i8, ptr %memoryref_data179, i64 %memoryref_byteoffset182
  %98 = load float, ptr %memoryref_data187, align 4
  %memoryref_byteoffset195 = shl i64 %value_phi160275, 2
  %memoryref_data200 = getelementptr inbounds i8, ptr %memoryref_data192, i64 %memoryref_byteoffset195
  %99 = load float, ptr %memoryref_data200, align 4
  %100 = fmul contract float %98, %99
  %101 = fadd reassoc contract float %value_phi159274, %100
  %102 = fmul contract float %99, %99
  %103 = fadd reassoc contract float %value_phi158273, %102
  %exitcond454.not = icmp eq i64 %97, %"m::SqrtLSModel.ls.r.size_ptr155.copyload"
  br i1 %exitcond454.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block596, %middle.block558, %L178, %L71, %vec.epilog.middle.block645, %middle.block615, %L58
  %value_phi59 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %85, %middle.block558 ], [ %96, %vec.epilog.middle.block596 ], [ %31, %middle.block615 ], [ %46, %vec.epilog.middle.block645 ], [ %103, %L190 ], [ %55, %L71 ]
  %value_phi60 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %84, %middle.block558 ], [ %95, %vec.epilog.middle.block596 ], [ %30, %middle.block615 ], [ %45, %vec.epilog.middle.block645 ], [ %101, %L190 ], [ %53, %L71 ]
  %value_phi61 = phi float [ 0.000000e+00, %L58 ], [ %6, %L178 ], [ %6, %middle.block558 ], [ %6, %vec.epilog.middle.block596 ], [ %29, %middle.block615 ], [ %44, %vec.epilog.middle.block645 ], [ %6, %L190 ], [ %51, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not223 = icmp ult i64 %5, %"xv::Array.size_ptr62.copyload"
  br i1 %.not223, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple153", align 8
  call void @j_throw_boundserror_3550(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple153") #15
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %104 = load float, ptr %memoryref_data73, align 4
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %"m::SqrtLSModel.ls75.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls75.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls75.r_ptr" unordered, align 8
  %"m::SqrtLSModel.gt_ptr.copyload224" = load float, ptr %"m::SqrtLSModel.gt_ptr", align 8
  %"m::SqrtLSModel.ls75.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls75.r", i64 16
  %"m::SqrtLSModel.ls75.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls75.r.size_ptr", align 8
  %105 = fsub float %value_phi61, %value_phi61
  %106 = fcmp uno float %105, 0.000000e+00
  %107 = sitofp i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload" to float
  %108 = fmul float %107, 0x3980000000000000
  %109 = fcmp ugt float %108, %value_phi61
  %.not230 = or i1 %106, %109
  %110 = fsub float %value_phi59, %value_phi59
  %111 = fcmp uno float %110, 0.000000e+00
  %112 = fcmp ugt float %108, %value_phi59
  %.not233 = or i1 %111, %112
  %.not227 = or i1 %.not230, %.not233
  br i1 %.not227, label %L506, label %L341

L341:                                             ; preds = %L311
  %113 = fcmp uge float %value_phi61, 0.000000e+00
  br i1 %113, label %L345, label %L343

L343:                                             ; preds = %L341
  call void @j_throw_complex_domainerror_3554(ptr nonnull @"jl_sym#sqrt#3555.jit", float %value_phi61) #15
  unreachable

L345:                                             ; preds = %L341
  %114 = call float @llvm.sqrt.f32(float %value_phi61)
  %115 = fcmp ugt float %114, %"m::SqrtLSModel.gt_ptr.copyload224"
  br i1 %115, label %L350, label %L510

L350:                                             ; preds = %L345
  %116 = fdiv float %value_phi60, %value_phi61
  %117 = fmul float %value_phi60, %116
  %118 = fsub float %value_phi59, %117
  %119 = fmul float %value_phi59, 6.250000e-02
  %120 = fcmp uge float %118, %119
  br i1 %120, label %L474, label %L356

L356:                                             ; preds = %L350
  %"m::SqrtLSModel.ls74.X.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr", align 8
  %121 = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 24
  %"m::SqrtLSModel.ls74.X.size_ptr90.copyload91" = load i64, ptr %121, align 8
  %.not234.not = icmp ult i64 %5, %"m::SqrtLSModel.ls74.X.size_ptr90.copyload91"
  br i1 %.not234.not, label %L383, label %L380

L380:                                             ; preds = %L356
  %122 = getelementptr inbounds nuw i8, ptr %"new::Tuple89", i64 8
  store i64 %value_phi9, ptr %122, align 1
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %"new::Tuple89", align 1
  %gc_slot_addr_0778 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls74.X", ptr %gc_slot_addr_0778, align 8
  call void @j_throw_boundserror_3557(ptr nonnull %"m::SqrtLSModel.ls74.X", ptr nocapture nonnull readonly %"new::Tuple89") #15
  unreachable

L383:                                             ; preds = %L356
  %123 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", %5
  %124 = icmp slt i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 1
  br i1 %124, label %L481, label %iter.check

iter.check:                                       ; preds = %L383
  %memoryref_data112 = load ptr, ptr %"m::SqrtLSModel.ls75.r", align 8
  %memoryref_data126 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L406, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check534 = icmp samesign ult i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 32
  br i1 %min.iters.check534, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 28
  %n.vec = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %116, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %147, %vector.body ]
  %vec.phi535 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %148, %vector.body ]
  %vec.phi536 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %149, %vector.body ]
  %vec.phi537 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %150, %vector.body ]
  %125 = shl i64 %index, 2
  %126 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %125
  %127 = getelementptr inbounds nuw i8, ptr %126, i64 32
  %128 = getelementptr inbounds nuw i8, ptr %126, i64 64
  %129 = getelementptr inbounds nuw i8, ptr %126, i64 96
  %wide.load = load <8 x float>, ptr %126, align 4
  %wide.load538 = load <8 x float>, ptr %127, align 4
  %wide.load539 = load <8 x float>, ptr %128, align 4
  %wide.load540 = load <8 x float>, ptr %129, align 4
  %.reass711 = add i64 %index, %123
  %130 = shl i64 %.reass711, 2
  %131 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %130
  %132 = getelementptr inbounds nuw i8, ptr %131, i64 32
  %133 = getelementptr inbounds nuw i8, ptr %131, i64 64
  %134 = getelementptr inbounds nuw i8, ptr %131, i64 96
  %wide.load541 = load <8 x float>, ptr %131, align 4
  %wide.load542 = load <8 x float>, ptr %132, align 4
  %wide.load543 = load <8 x float>, ptr %133, align 4
  %wide.load544 = load <8 x float>, ptr %134, align 4
  %135 = fmul <8 x float> %broadcast.splat, %wide.load541
  %136 = fmul <8 x float> %broadcast.splat, %wide.load542
  %137 = fmul <8 x float> %broadcast.splat, %wide.load543
  %138 = fmul <8 x float> %broadcast.splat, %wide.load544
  %139 = fsub <8 x float> %wide.load, %135
  %140 = fsub <8 x float> %wide.load538, %136
  %141 = fsub <8 x float> %wide.load539, %137
  %142 = fsub <8 x float> %wide.load540, %138
  %143 = fmul contract <8 x float> %139, %139
  %144 = fmul contract <8 x float> %140, %140
  %145 = fmul contract <8 x float> %141, %141
  %146 = fmul contract <8 x float> %142, %142
  %147 = fadd reassoc contract <8 x float> %vec.phi, %143
  %148 = fadd reassoc contract <8 x float> %vec.phi535, %144
  %149 = fadd reassoc contract <8 x float> %vec.phi536, %145
  %150 = fadd reassoc contract <8 x float> %vec.phi537, %146
  %index.next = add nuw i64 %index, 32
  %151 = icmp eq i64 %index.next, %n.vec
  br i1 %151, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %148, %147
  %bin.rdx545 = fadd reassoc contract <8 x float> %149, %bin.rdx
  %bin.rdx546 = fadd reassoc contract <8 x float> %150, %bin.rdx545
  %152 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx546)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L474, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L406, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi float [ %152, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec548 = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 9223372036854775804
  %153 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx, i64 0
  %broadcast.splatinsert553 = insertelement <4 x float> poison, float %116, i64 0
  %broadcast.splat554 = shufflevector <4 x float> %broadcast.splatinsert553, <4 x float> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index549 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next555, %vec.epilog.vector.body ]
  %vec.phi550 = phi <4 x float> [ %153, %vec.epilog.ph ], [ %159, %vec.epilog.vector.body ]
  %154 = shl i64 %index549, 2
  %gep713 = getelementptr i8, ptr %memoryref_data112, i64 %154
  %wide.load551 = load <4 x float>, ptr %gep713, align 4
  %.reass715 = add i64 %index549, %123
  %155 = shl i64 %.reass715, 2
  %gep717 = getelementptr i8, ptr %memoryref_data126, i64 %155
  %wide.load552 = load <4 x float>, ptr %gep717, align 4
  %156 = fmul <4 x float> %broadcast.splat554, %wide.load552
  %157 = fsub <4 x float> %wide.load551, %156
  %158 = fmul contract <4 x float> %157, %157
  %159 = fadd reassoc contract <4 x float> %vec.phi550, %158
  %index.next555 = add nuw i64 %index549, 4
  %160 = icmp eq i64 %index.next555, %n.vec548
  br i1 %160, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %161 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %159)
  %cmp.n556 = icmp eq i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", %n.vec548
  br i1 %cmp.n556, label %L474, label %L406

L406:                                             ; preds = %L406, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi105277 = phi i64 [ %162, %L406 ], [ %n.vec548, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi104276 = phi float [ %168, %L406 ], [ %161, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %152, %vec.epilog.iter.check ]
  %162 = add nuw nsw i64 %value_phi105277, 1
  %memoryref_byteoffset115 = shl i64 %value_phi105277, 2
  %memoryref_data120 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %memoryref_byteoffset115
  %163 = load float, ptr %memoryref_data120, align 4
  %memoryref_offset128 = add i64 %value_phi105277, %123
  %memoryref_byteoffset129 = shl i64 %memoryref_offset128, 2
  %memoryref_data134 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %memoryref_byteoffset129
  %164 = load float, ptr %memoryref_data134, align 4
  %165 = fmul float %116, %164
  %166 = fsub float %163, %165
  %167 = fmul contract float %166, %166
  %168 = fadd reassoc contract float %value_phi104276, %167
  %exitcond455.not = icmp eq i64 %162, %"m::SqrtLSModel.ls75.r.size_ptr.copyload"
  br i1 %exitcond455.not, label %L474, label %L406

L474:                                             ; preds = %L406, %vec.epilog.middle.block, %middle.block, %L350
  %value_phi142 = phi float [ %118, %L350 ], [ %152, %middle.block ], [ %161, %vec.epilog.middle.block ], [ %168, %L406 ]
  %169 = fcmp uge float %value_phi142, 0.000000e+00
  br i1 %169, label %L481, label %L479

L479:                                             ; preds = %L474
  call void @j_throw_complex_domainerror_3554(ptr nonnull @"jl_sym#sqrt#3555.jit", float %value_phi142) #15
  unreachable

L481:                                             ; preds = %L474, %L383
  %value_phi142239 = phi float [ %value_phi142, %L474 ], [ 0.000000e+00, %L383 ]
  %170 = fadd float %116, %104
  %171 = fdiv float %"m::SqrtLSModel.gt_ptr.copyload224", %114
  %172 = call float @llvm.sqrt.f32(float %value_phi142239)
  %173 = fsub float %114, %"m::SqrtLSModel.gt_ptr.copyload224"
  %174 = fcmp uge float %173, 0.000000e+00
  br i1 %174, label %L488, label %L486

L486:                                             ; preds = %L481
  call void @j_throw_complex_domainerror_3554(ptr nonnull @"jl_sym#sqrt#3555.jit", float %173) #15
  unreachable

L488:                                             ; preds = %L481
  %175 = fadd float %114, %"m::SqrtLSModel.gt_ptr.copyload224"
  %176 = fcmp uge float %175, 0.000000e+00
  br i1 %176, label %L495, label %L493

L493:                                             ; preds = %L488
  call void @j_throw_complex_domainerror_3554(ptr nonnull @"jl_sym#sqrt#3555.jit", float %175) #15
  unreachable

L495:                                             ; preds = %L488
  %177 = call float @llvm.sqrt.f32(float %173)
  %178 = call float @llvm.sqrt.f32(float %175)
  %179 = fmul float %177, %178
  %180 = fdiv float %172, %179
  %181 = fmul float %171, %180
  %182 = fsub float %170, %181
  %183 = call float @llvm.maximum.f32(float %182, float 0.000000e+00)
  %184 = fadd float %170, %181
  %185 = call float @llvm.minimum.f32(float %184, float 0.000000e+00)
  %186 = fadd float %183, %185
  br label %L510

L506:                                             ; preds = %L311
  %gc_slot_addr_0779 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0779, align 8
  %187 = call float @j__sqrt_cold_3558(ptr nonnull %"m::SqrtLSModel", float %104, float %value_phi61, i64 signext %value_phi9)
  br label %L510

L510:                                             ; preds = %L506, %L495, %L345
  %value_phi78 = phi float [ %186, %L495 ], [ %187, %L506 ], [ 0.000000e+00, %L345 ]
  %188 = fadd float %value_phi8, %value_phi78
  %.not236 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %189 = add nuw i64 %value_phi9, 1
  br i1 %.not236, label %L522, label %L31

L522:                                             ; preds = %L510, %L17
  %value_phi83 = phi float [ %value_phi4, %L17 ], [ %188, %L510 ]
  %.not237 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not237, label %L533, label %L17thread-pre-split

L533:                                             ; preds = %L522, %L17.preheader, %top
  %value_phi86 = phi float [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi83, %L522 ]
  %frame.prev786 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev786, ptr %tls_pgcstack, align 8
  ret float %value_phi86
}
