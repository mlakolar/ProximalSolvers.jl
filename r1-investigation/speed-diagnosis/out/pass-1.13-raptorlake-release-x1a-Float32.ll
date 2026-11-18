; Function Signature: pass(typeof(M_x1a.ProximalSolvers._column_dot_rsqr), typeof(M_x1a.ProximalSolvers._sqrt_minimizer), M_x1a.ProximalSolvers.SqrtLSModel{Float32, M_x1a.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
; Function Attrs: noinline
define float @julia_pass_3927(ptr noundef nonnull align 8 dereferenceable(72) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [6 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 48, i1 true)
  %0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 24
  %1 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  %"new::Tuple77" = alloca { [1 x [1 x i64]], i64 }, align 8
  %"new::SubArray" = alloca [5 x i64], align 8
  %"m::SqrtLSModel.gt" = alloca i32, align 4
  %"new::Tuple165" = alloca [1 x i64], align 8
  %"new::Tuple221" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 16, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %".reps::Int64" = call i64 @llvm.smax.i64(i64 %"reps::Int64", i64 0)
  %2 = icmp slt i64 %"reps::Int64", 1
  br i1 %2, label %L588, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %"m::SqrtLSModel.ls" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"xv::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"xv::Array", i64 16
  %"m::SqrtLSModel.ls.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 24
  %"m::SqrtLSModel.ls.a_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 32
  %3 = getelementptr inbounds nuw i8, ptr %"new::SubArray", i64 8
  %4 = getelementptr inbounds nuw i8, ptr %"new::SubArray", i64 16
  %5 = getelementptr inbounds nuw i8, ptr %"new::SubArray", i64 24
  %6 = getelementptr inbounds nuw i8, ptr %"new::SubArray", i64 32
  %"m::SqrtLSModel.gt_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel", i64 8
  %7 = load i64, ptr %"xv::Array.size_ptr", align 8
  %8 = icmp slt i64 %7, 1
  br i1 %8, label %L588, label %L17

L17thread-pre-split:                              ; preds = %L577
  %9 = add nuw i64 %value_phi3, 1
  %"xv::Array.size_ptr.copyload.pr" = load i64, ptr %"xv::Array.size_ptr", align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %"xv::Array.size_ptr.copyload" = phi i64 [ %"xv::Array.size_ptr.copyload.pr", %L17thread-pre-split ], [ %7, %L17.preheader ]
  %value_phi3 = phi i64 [ %9, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi97, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %10 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %10, label %L577, label %L31

L31:                                              ; preds = %L565, %L17
  %value_phi8 = phi float [ %215, %L565 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %216, %L565 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %11 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %11, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple221", align 8
  %gc_slot_addr_2 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 32
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_2, align 8
  call void @j_throw_boundserror_3929(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple221") #16
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %11, 2
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %12 = load float, ptr %memoryref_data11, align 4
  %13 = fcmp ord float %12, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr167" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr167.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr167", align 8
  %14 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 1
  br i1 %13, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %14, label %L299, label %iter.check656

iter.check656:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %15 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %11
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check654 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 4
  br i1 %min.iters.check654, label %L71, label %vector.main.loop.iter.check658

vector.main.loop.iter.check658:                   ; preds = %iter.check656
  %min.iters.check657 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 16
  br i1 %min.iters.check657, label %vec.epilog.ph685, label %vector.ph659

vector.ph659:                                     ; preds = %vector.main.loop.iter.check658
  %n.mod.vf660 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 12
  %n.vec661 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775792
  br label %vector.body662

vector.body662:                                   ; preds = %vector.body662, %vector.ph659
  %index663 = phi i64 [ 0, %vector.ph659 ], [ %index.next674, %vector.body662 ]
  %vec.phi664 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph659 ], [ %24, %vector.body662 ]
  %vec.phi665 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph659 ], [ %25, %vector.body662 ]
  %vec.phi666 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph659 ], [ %28, %vector.body662 ]
  %vec.phi667 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph659 ], [ %29, %vector.body662 ]
  %vec.phi668 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph659 ], [ %32, %vector.body662 ]
  %vec.phi669 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph659 ], [ %33, %vector.body662 ]
  %.reass = add i64 %index663, %15
  %16 = shl i64 %.reass, 2
  %17 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %16
  %18 = getelementptr inbounds nuw i8, ptr %17, i64 32
  %wide.load670 = load <8 x float>, ptr %17, align 4
  %wide.load671 = load <8 x float>, ptr %18, align 4
  %19 = shl i64 %index663, 2
  %20 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %19
  %21 = getelementptr inbounds nuw i8, ptr %20, i64 32
  %wide.load672 = load <8 x float>, ptr %20, align 4
  %wide.load673 = load <8 x float>, ptr %21, align 4
  %22 = fmul contract <8 x float> %wide.load670, %wide.load670
  %23 = fmul contract <8 x float> %wide.load671, %wide.load671
  %24 = fadd reassoc contract <8 x float> %vec.phi664, %22
  %25 = fadd reassoc contract <8 x float> %vec.phi665, %23
  %26 = fmul contract <8 x float> %wide.load670, %wide.load672
  %27 = fmul contract <8 x float> %wide.load671, %wide.load673
  %28 = fadd reassoc contract <8 x float> %vec.phi666, %26
  %29 = fadd reassoc contract <8 x float> %vec.phi667, %27
  %30 = fmul contract <8 x float> %wide.load672, %wide.load672
  %31 = fmul contract <8 x float> %wide.load673, %wide.load673
  %32 = fadd reassoc contract <8 x float> %vec.phi668, %30
  %33 = fadd reassoc contract <8 x float> %vec.phi669, %31
  %index.next674 = add nuw i64 %index663, 16
  %34 = icmp eq i64 %index.next674, %n.vec661
  br i1 %34, label %middle.block653, label %vector.body662

middle.block653:                                  ; preds = %vector.body662
  %bin.rdx675 = fadd reassoc contract <8 x float> %25, %24
  %35 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx675)
  %bin.rdx676 = fadd reassoc contract <8 x float> %29, %28
  %36 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx676)
  %bin.rdx677 = fadd reassoc contract <8 x float> %33, %32
  %37 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx677)
  %cmp.n678 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec661
  br i1 %cmp.n678, label %L299, label %vec.epilog.iter.check686

vec.epilog.iter.check686:                         ; preds = %middle.block653
  %min.epilog.iters.check688 = icmp eq i64 %n.mod.vf660, 0
  br i1 %min.epilog.iters.check688, label %L71, label %vec.epilog.ph685

vec.epilog.ph685:                                 ; preds = %vec.epilog.iter.check686, %vector.main.loop.iter.check658
  %vec.epilog.resume.val679 = phi i64 [ %n.vec661, %vec.epilog.iter.check686 ], [ 0, %vector.main.loop.iter.check658 ]
  %bc.merge.rdx680 = phi float [ %35, %vec.epilog.iter.check686 ], [ 0.000000e+00, %vector.main.loop.iter.check658 ]
  %bc.merge.rdx681 = phi float [ %36, %vec.epilog.iter.check686 ], [ 0.000000e+00, %vector.main.loop.iter.check658 ]
  %bc.merge.rdx682 = phi float [ %37, %vec.epilog.iter.check686 ], [ 0.000000e+00, %vector.main.loop.iter.check658 ]
  %n.vec690 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775804
  %38 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx680, i64 0
  %39 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx681, i64 0
  %40 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx682, i64 0
  br label %vec.epilog.vector.body691

vec.epilog.vector.body691:                        ; preds = %vec.epilog.vector.body691, %vec.epilog.ph685
  %index692 = phi i64 [ %vec.epilog.resume.val679, %vec.epilog.ph685 ], [ %index.next698, %vec.epilog.vector.body691 ]
  %vec.phi693 = phi <4 x float> [ %38, %vec.epilog.ph685 ], [ %44, %vec.epilog.vector.body691 ]
  %vec.phi694 = phi <4 x float> [ %39, %vec.epilog.ph685 ], [ %46, %vec.epilog.vector.body691 ]
  %vec.phi695 = phi <4 x float> [ %40, %vec.epilog.ph685 ], [ %48, %vec.epilog.vector.body691 ]
  %.reass737 = add i64 %index692, %15
  %41 = shl i64 %.reass737, 2
  %gep = getelementptr i8, ptr %memoryref_data30, i64 %41
  %wide.load696 = load <4 x float>, ptr %gep, align 4
  %42 = shl i64 %index692, 2
  %gep739 = getelementptr i8, ptr %memoryref_data42, i64 %42
  %wide.load697 = load <4 x float>, ptr %gep739, align 4
  %43 = fmul contract <4 x float> %wide.load696, %wide.load696
  %44 = fadd reassoc contract <4 x float> %vec.phi693, %43
  %45 = fmul contract <4 x float> %wide.load696, %wide.load697
  %46 = fadd reassoc contract <4 x float> %vec.phi694, %45
  %47 = fmul contract <4 x float> %wide.load697, %wide.load697
  %48 = fadd reassoc contract <4 x float> %vec.phi695, %47
  %index.next698 = add nuw i64 %index692, 4
  %49 = icmp eq i64 %index.next698, %n.vec690
  br i1 %49, label %vec.epilog.middle.block683, label %vec.epilog.vector.body691

vec.epilog.middle.block683:                       ; preds = %vec.epilog.vector.body691
  %50 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %44)
  %51 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %46)
  %52 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %48)
  %cmp.n699 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec690
  br i1 %cmp.n699, label %L299, label %L71

L71:                                              ; preds = %L71, %vec.epilog.middle.block683, %vec.epilog.iter.check686, %iter.check656
  %value_phi15288 = phi float [ %57, %L71 ], [ %50, %vec.epilog.middle.block683 ], [ 0.000000e+00, %iter.check656 ], [ %35, %vec.epilog.iter.check686 ]
  %value_phi14287 = phi i64 [ %53, %L71 ], [ %n.vec690, %vec.epilog.middle.block683 ], [ 0, %iter.check656 ], [ %n.vec661, %vec.epilog.iter.check686 ]
  %value_phi13286 = phi float [ %59, %L71 ], [ %51, %vec.epilog.middle.block683 ], [ 0.000000e+00, %iter.check656 ], [ %36, %vec.epilog.iter.check686 ]
  %value_phi12285 = phi float [ %61, %L71 ], [ %52, %vec.epilog.middle.block683 ], [ 0.000000e+00, %iter.check656 ], [ %37, %vec.epilog.iter.check686 ]
  %53 = add nuw nsw i64 %value_phi14287, 1
  %memoryref_offset32 = add i64 %15, %value_phi14287
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 2
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %54 = load float, ptr %memoryref_data38, align 4
  %memoryref_byteoffset45 = shl i64 %value_phi14287, 2
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %55 = load float, ptr %memoryref_data50, align 4
  %56 = fmul contract float %54, %54
  %57 = fadd reassoc contract float %value_phi15288, %56
  %58 = fmul contract float %54, %55
  %59 = fadd reassoc contract float %value_phi13286, %58
  %60 = fmul contract float %55, %55
  %61 = fadd reassoc contract float %value_phi12285, %60
  %exitcond.not = icmp eq i64 %53, %"m::SqrtLSModel.ls.r.size_ptr167.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %14, label %L299, label %iter.check599

iter.check599:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr184" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr184.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr184", align 8
  %62 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr184.copyload", %11
  %memoryref_data191 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data204 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check597 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 4
  br i1 %min.iters.check597, label %L190, label %vector.main.loop.iter.check601

vector.main.loop.iter.check601:                   ; preds = %iter.check599
  %min.iters.check600 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 32
  br i1 %min.iters.check600, label %vec.epilog.ph636, label %vector.ph602

vector.ph602:                                     ; preds = %vector.main.loop.iter.check601
  %n.mod.vf603 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 28
  %n.vec604 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775776
  br label %vector.body605

vector.body605:                                   ; preds = %vector.body605, %vector.ph602
  %index606 = phi i64 [ 0, %vector.ph602 ], [ %index.next623, %vector.body605 ]
  %vec.phi607 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph602 ], [ %77, %vector.body605 ]
  %vec.phi608 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %78, %vector.body605 ]
  %vec.phi609 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %79, %vector.body605 ]
  %vec.phi610 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %80, %vector.body605 ]
  %vec.phi611 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph602 ], [ %85, %vector.body605 ]
  %vec.phi612 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %86, %vector.body605 ]
  %vec.phi613 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %87, %vector.body605 ]
  %vec.phi614 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph602 ], [ %88, %vector.body605 ]
  %.reass741 = add i64 %index606, %62
  %63 = shl i64 %.reass741, 2
  %64 = getelementptr inbounds i8, ptr %memoryref_data191, i64 %63
  %65 = getelementptr inbounds nuw i8, ptr %64, i64 32
  %66 = getelementptr inbounds nuw i8, ptr %64, i64 64
  %67 = getelementptr inbounds nuw i8, ptr %64, i64 96
  %wide.load615 = load <8 x float>, ptr %64, align 4
  %wide.load616 = load <8 x float>, ptr %65, align 4
  %wide.load617 = load <8 x float>, ptr %66, align 4
  %wide.load618 = load <8 x float>, ptr %67, align 4
  %68 = shl i64 %index606, 2
  %69 = getelementptr inbounds i8, ptr %memoryref_data204, i64 %68
  %70 = getelementptr inbounds nuw i8, ptr %69, i64 32
  %71 = getelementptr inbounds nuw i8, ptr %69, i64 64
  %72 = getelementptr inbounds nuw i8, ptr %69, i64 96
  %wide.load619 = load <8 x float>, ptr %69, align 4
  %wide.load620 = load <8 x float>, ptr %70, align 4
  %wide.load621 = load <8 x float>, ptr %71, align 4
  %wide.load622 = load <8 x float>, ptr %72, align 4
  %73 = fmul contract <8 x float> %wide.load615, %wide.load619
  %74 = fmul contract <8 x float> %wide.load616, %wide.load620
  %75 = fmul contract <8 x float> %wide.load617, %wide.load621
  %76 = fmul contract <8 x float> %wide.load618, %wide.load622
  %77 = fadd reassoc contract <8 x float> %vec.phi607, %73
  %78 = fadd reassoc contract <8 x float> %vec.phi608, %74
  %79 = fadd reassoc contract <8 x float> %vec.phi609, %75
  %80 = fadd reassoc contract <8 x float> %vec.phi610, %76
  %81 = fmul contract <8 x float> %wide.load619, %wide.load619
  %82 = fmul contract <8 x float> %wide.load620, %wide.load620
  %83 = fmul contract <8 x float> %wide.load621, %wide.load621
  %84 = fmul contract <8 x float> %wide.load622, %wide.load622
  %85 = fadd reassoc contract <8 x float> %vec.phi611, %81
  %86 = fadd reassoc contract <8 x float> %vec.phi612, %82
  %87 = fadd reassoc contract <8 x float> %vec.phi613, %83
  %88 = fadd reassoc contract <8 x float> %vec.phi614, %84
  %index.next623 = add nuw i64 %index606, 32
  %89 = icmp eq i64 %index.next623, %n.vec604
  br i1 %89, label %middle.block596, label %vector.body605

middle.block596:                                  ; preds = %vector.body605
  %bin.rdx624 = fadd reassoc contract <8 x float> %78, %77
  %bin.rdx625 = fadd reassoc contract <8 x float> %79, %bin.rdx624
  %bin.rdx626 = fadd reassoc contract <8 x float> %80, %bin.rdx625
  %90 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx626)
  %bin.rdx627 = fadd reassoc contract <8 x float> %86, %85
  %bin.rdx628 = fadd reassoc contract <8 x float> %87, %bin.rdx627
  %bin.rdx629 = fadd reassoc contract <8 x float> %88, %bin.rdx628
  %91 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx629)
  %cmp.n630 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec604
  br i1 %cmp.n630, label %L299, label %vec.epilog.iter.check637

vec.epilog.iter.check637:                         ; preds = %middle.block596
  %min.epilog.iters.check639 = icmp eq i64 %n.mod.vf603, 0
  br i1 %min.epilog.iters.check639, label %L190, label %vec.epilog.ph636

vec.epilog.ph636:                                 ; preds = %vec.epilog.iter.check637, %vector.main.loop.iter.check601
  %vec.epilog.resume.val631 = phi i64 [ %n.vec604, %vec.epilog.iter.check637 ], [ 0, %vector.main.loop.iter.check601 ]
  %bc.merge.rdx632 = phi float [ %90, %vec.epilog.iter.check637 ], [ 0.000000e+00, %vector.main.loop.iter.check601 ]
  %bc.merge.rdx633 = phi float [ %91, %vec.epilog.iter.check637 ], [ 0.000000e+00, %vector.main.loop.iter.check601 ]
  %n.vec641 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775804
  %92 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx632, i64 0
  %93 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx633, i64 0
  br label %vec.epilog.vector.body642

vec.epilog.vector.body642:                        ; preds = %vec.epilog.vector.body642, %vec.epilog.ph636
  %index643 = phi i64 [ %vec.epilog.resume.val631, %vec.epilog.ph636 ], [ %index.next648, %vec.epilog.vector.body642 ]
  %vec.phi644 = phi <4 x float> [ %92, %vec.epilog.ph636 ], [ %97, %vec.epilog.vector.body642 ]
  %vec.phi645 = phi <4 x float> [ %93, %vec.epilog.ph636 ], [ %99, %vec.epilog.vector.body642 ]
  %.reass743 = add i64 %index643, %62
  %94 = shl i64 %.reass743, 2
  %gep745 = getelementptr i8, ptr %memoryref_data191, i64 %94
  %wide.load646 = load <4 x float>, ptr %gep745, align 4
  %95 = shl i64 %index643, 2
  %gep747 = getelementptr i8, ptr %memoryref_data204, i64 %95
  %wide.load647 = load <4 x float>, ptr %gep747, align 4
  %96 = fmul contract <4 x float> %wide.load646, %wide.load647
  %97 = fadd reassoc contract <4 x float> %vec.phi644, %96
  %98 = fmul contract <4 x float> %wide.load647, %wide.load647
  %99 = fadd reassoc contract <4 x float> %vec.phi645, %98
  %index.next648 = add nuw i64 %index643, 4
  %100 = icmp eq i64 %index.next648, %n.vec641
  br i1 %100, label %vec.epilog.middle.block634, label %vec.epilog.vector.body642

vec.epilog.middle.block634:                       ; preds = %vec.epilog.vector.body642
  %101 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %97)
  %102 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %99)
  %cmp.n649 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec641
  br i1 %cmp.n649, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block634, %vec.epilog.iter.check637, %iter.check599
  %value_phi172291 = phi i64 [ %103, %L190 ], [ %n.vec641, %vec.epilog.middle.block634 ], [ 0, %iter.check599 ], [ %n.vec604, %vec.epilog.iter.check637 ]
  %value_phi171290 = phi float [ %107, %L190 ], [ %101, %vec.epilog.middle.block634 ], [ 0.000000e+00, %iter.check599 ], [ %90, %vec.epilog.iter.check637 ]
  %value_phi170289 = phi float [ %109, %L190 ], [ %102, %vec.epilog.middle.block634 ], [ 0.000000e+00, %iter.check599 ], [ %91, %vec.epilog.iter.check637 ]
  %103 = add nuw nsw i64 %value_phi172291, 1
  %memoryref_offset193 = add i64 %62, %value_phi172291
  %memoryref_byteoffset194 = shl i64 %memoryref_offset193, 2
  %memoryref_data199 = getelementptr inbounds i8, ptr %memoryref_data191, i64 %memoryref_byteoffset194
  %104 = load float, ptr %memoryref_data199, align 4
  %memoryref_byteoffset207 = shl i64 %value_phi172291, 2
  %memoryref_data212 = getelementptr inbounds i8, ptr %memoryref_data204, i64 %memoryref_byteoffset207
  %105 = load float, ptr %memoryref_data212, align 4
  %106 = fmul contract float %104, %105
  %107 = fadd reassoc contract float %value_phi171290, %106
  %108 = fmul contract float %105, %105
  %109 = fadd reassoc contract float %value_phi170289, %108
  %exitcond476.not = icmp eq i64 %103, %"m::SqrtLSModel.ls.r.size_ptr167.copyload"
  br i1 %exitcond476.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block634, %middle.block596, %L178, %L71, %vec.epilog.middle.block683, %middle.block653, %L58
  %value_phi59 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %91, %middle.block596 ], [ %102, %vec.epilog.middle.block634 ], [ %37, %middle.block653 ], [ %52, %vec.epilog.middle.block683 ], [ %109, %L190 ], [ %61, %L71 ]
  %value_phi60 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %90, %middle.block596 ], [ %101, %vec.epilog.middle.block634 ], [ %36, %middle.block653 ], [ %51, %vec.epilog.middle.block683 ], [ %107, %L190 ], [ %59, %L71 ]
  %value_phi61 = phi float [ 0.000000e+00, %L58 ], [ %12, %L178 ], [ %12, %middle.block596 ], [ %12, %vec.epilog.middle.block634 ], [ %35, %middle.block653 ], [ %50, %vec.epilog.middle.block683 ], [ %12, %L190 ], [ %57, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not235 = icmp ult i64 %11, %"xv::Array.size_ptr62.copyload"
  br i1 %.not235, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple165", align 8
  call void @j_throw_boundserror_3929(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple165") #16
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %110 = load float, ptr %memoryref_data73, align 4
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %"m::SqrtLSModel.ls74.X.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr", align 8
  %111 = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 24
  %"m::SqrtLSModel.ls74.X.size_ptr78.copyload79" = load i64, ptr %111, align 8
  %.not236.not = icmp ult i64 %11, %"m::SqrtLSModel.ls74.X.size_ptr78.copyload79"
  br i1 %.not236.not, label %L344, label %L341

L341:                                             ; preds = %L311
  %112 = getelementptr inbounds nuw i8, ptr %"new::Tuple77", i64 8
  store i64 %value_phi9, ptr %112, align 1
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %"new::Tuple77", align 1
  %gc_slot_addr_2821 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 32
  store ptr %"m::SqrtLSModel.ls74.X", ptr %gc_slot_addr_2821, align 8
  call void @j_throw_boundserror_3938(ptr nonnull %"m::SqrtLSModel.ls74.X", ptr nocapture nonnull readonly %"new::Tuple77") #16
  unreachable

L344:                                             ; preds = %L311
  %113 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", %11
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %3, align 8
  store i64 %value_phi9, ptr %4, align 8
  store i64 %113, ptr %5, align 8
  store i64 1, ptr %6, align 8
  %"m::SqrtLSModel.ls89.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls89.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls89.r_ptr" unordered, align 8
  %"m::SqrtLSModel.gt_ptr.copyload" = load i32, ptr %"m::SqrtLSModel.gt_ptr", align 8
  store i32 %"m::SqrtLSModel.gt_ptr.copyload", ptr %"m::SqrtLSModel.gt", align 4
  %"m::SqrtLSModel.ls89.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls89.r", i64 16
  %"m::SqrtLSModel.ls89.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls89.r.size_ptr", align 8
  %114 = fsub float %value_phi61, %value_phi61
  %115 = fcmp uno float %114, 0.000000e+00
  %116 = sitofp i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload" to float
  %117 = fmul float %116, 0x3980000000000000
  %118 = fcmp ugt float %117, %value_phi61
  %.not242 = or i1 %115, %118
  %119 = fsub float %value_phi59, %value_phi59
  %120 = fcmp uno float %119, 0.000000e+00
  %121 = fcmp ugt float %117, %value_phi59
  %.not245 = or i1 %120, %121
  %.not239 = or i1 %.not242, %.not245
  %122 = bitcast i32 %"m::SqrtLSModel.gt_ptr.copyload" to float
  br i1 %.not239, label %L561, label %L378

L378:                                             ; preds = %L344
  %123 = fcmp uge float %value_phi61, 0.000000e+00
  br i1 %123, label %L383, label %L381

L381:                                             ; preds = %L378
  call void @j_throw_complex_domainerror_3933(ptr nonnull @"jl_sym#sqrt#3934.jit", float %value_phi61) #16
  unreachable

L383:                                             ; preds = %L378
  %124 = call float @llvm.sqrt.f32(float %value_phi61)
  %125 = fcmp ugt float %124, %122
  br i1 %125, label %L387, label %L565

L387:                                             ; preds = %L383
  %126 = fdiv float %value_phi60, %value_phi61
  %127 = fadd float %126, %110
  %128 = fmul float %value_phi60, %126
  %129 = fsub float %value_phi59, %128
  %130 = fmul float %value_phi59, 6.250000e-02
  %131 = fcmp uge float %129, %130
  br i1 %131, label %L471, label %L394

L394:                                             ; preds = %L387
  %132 = icmp slt i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 1
  br i1 %132, label %L476, label %iter.check

iter.check:                                       ; preds = %L394
  %memoryref_data112 = load ptr, ptr %"m::SqrtLSModel.ls89.r", align 8
  %memoryref_data126 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L405, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check572 = icmp samesign ult i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 32
  br i1 %min.iters.check572, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 28
  %n.vec = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %126, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %155, %vector.body ]
  %vec.phi573 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %156, %vector.body ]
  %vec.phi574 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %157, %vector.body ]
  %vec.phi575 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %158, %vector.body ]
  %133 = shl i64 %index, 2
  %134 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %133
  %135 = getelementptr inbounds nuw i8, ptr %134, i64 32
  %136 = getelementptr inbounds nuw i8, ptr %134, i64 64
  %137 = getelementptr inbounds nuw i8, ptr %134, i64 96
  %wide.load = load <8 x float>, ptr %134, align 4
  %wide.load576 = load <8 x float>, ptr %135, align 4
  %wide.load577 = load <8 x float>, ptr %136, align 4
  %wide.load578 = load <8 x float>, ptr %137, align 4
  %.reass749 = add i64 %index, %113
  %138 = shl i64 %.reass749, 2
  %139 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %138
  %140 = getelementptr inbounds nuw i8, ptr %139, i64 32
  %141 = getelementptr inbounds nuw i8, ptr %139, i64 64
  %142 = getelementptr inbounds nuw i8, ptr %139, i64 96
  %wide.load579 = load <8 x float>, ptr %139, align 4
  %wide.load580 = load <8 x float>, ptr %140, align 4
  %wide.load581 = load <8 x float>, ptr %141, align 4
  %wide.load582 = load <8 x float>, ptr %142, align 4
  %143 = fmul <8 x float> %broadcast.splat, %wide.load579
  %144 = fmul <8 x float> %broadcast.splat, %wide.load580
  %145 = fmul <8 x float> %broadcast.splat, %wide.load581
  %146 = fmul <8 x float> %broadcast.splat, %wide.load582
  %147 = fsub <8 x float> %wide.load, %143
  %148 = fsub <8 x float> %wide.load576, %144
  %149 = fsub <8 x float> %wide.load577, %145
  %150 = fsub <8 x float> %wide.load578, %146
  %151 = fmul contract <8 x float> %147, %147
  %152 = fmul contract <8 x float> %148, %148
  %153 = fmul contract <8 x float> %149, %149
  %154 = fmul contract <8 x float> %150, %150
  %155 = fadd reassoc contract <8 x float> %vec.phi, %151
  %156 = fadd reassoc contract <8 x float> %vec.phi573, %152
  %157 = fadd reassoc contract <8 x float> %vec.phi574, %153
  %158 = fadd reassoc contract <8 x float> %vec.phi575, %154
  %index.next = add nuw i64 %index, 32
  %159 = icmp eq i64 %index.next, %n.vec
  br i1 %159, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %156, %155
  %bin.rdx583 = fadd reassoc contract <8 x float> %157, %bin.rdx
  %bin.rdx584 = fadd reassoc contract <8 x float> %158, %bin.rdx583
  %160 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx584)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L471, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L405, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi float [ %160, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec586 = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 9223372036854775804
  %161 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx, i64 0
  %broadcast.splatinsert591 = insertelement <4 x float> poison, float %126, i64 0
  %broadcast.splat592 = shufflevector <4 x float> %broadcast.splatinsert591, <4 x float> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index587 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next593, %vec.epilog.vector.body ]
  %vec.phi588 = phi <4 x float> [ %161, %vec.epilog.ph ], [ %167, %vec.epilog.vector.body ]
  %162 = shl i64 %index587, 2
  %gep751 = getelementptr i8, ptr %memoryref_data112, i64 %162
  %wide.load589 = load <4 x float>, ptr %gep751, align 4
  %.reass753 = add i64 %index587, %113
  %163 = shl i64 %.reass753, 2
  %gep755 = getelementptr i8, ptr %memoryref_data126, i64 %163
  %wide.load590 = load <4 x float>, ptr %gep755, align 4
  %164 = fmul <4 x float> %broadcast.splat592, %wide.load590
  %165 = fsub <4 x float> %wide.load589, %164
  %166 = fmul contract <4 x float> %165, %165
  %167 = fadd reassoc contract <4 x float> %vec.phi588, %166
  %index.next593 = add nuw i64 %index587, 4
  %168 = icmp eq i64 %index.next593, %n.vec586
  br i1 %168, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %169 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %167)
  %cmp.n594 = icmp eq i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", %n.vec586
  br i1 %cmp.n594, label %L471, label %L405

L405:                                             ; preds = %L405, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi105293 = phi i64 [ %170, %L405 ], [ %n.vec586, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi104292 = phi float [ %176, %L405 ], [ %169, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %160, %vec.epilog.iter.check ]
  %170 = add nuw nsw i64 %value_phi105293, 1
  %memoryref_byteoffset115 = shl i64 %value_phi105293, 2
  %memoryref_data120 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %memoryref_byteoffset115
  %171 = load float, ptr %memoryref_data120, align 4
  %memoryref_offset128 = add i64 %value_phi105293, %113
  %memoryref_byteoffset129 = shl i64 %memoryref_offset128, 2
  %memoryref_data134 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %memoryref_byteoffset129
  %172 = load float, ptr %memoryref_data134, align 4
  %173 = fmul float %126, %172
  %174 = fsub float %171, %173
  %175 = fmul contract float %174, %174
  %176 = fadd reassoc contract float %value_phi104292, %175
  %exitcond477.not = icmp eq i64 %170, %"m::SqrtLSModel.ls89.r.size_ptr.copyload"
  br i1 %exitcond477.not, label %L471, label %L405

L471:                                             ; preds = %L405, %vec.epilog.middle.block, %middle.block, %L387
  %value_phi142 = phi float [ %129, %L387 ], [ %160, %middle.block ], [ %169, %vec.epilog.middle.block ], [ %176, %L405 ]
  %177 = fcmp uge float %value_phi142, 0.000000e+00
  br i1 %177, label %L476, label %L474

L474:                                             ; preds = %L471
  call void @j_throw_complex_domainerror_3933(ptr nonnull @"jl_sym#sqrt#3934.jit", float %value_phi142) #16
  unreachable

L476:                                             ; preds = %L471, %L394
  %value_phi142255 = phi float [ %value_phi142, %L471 ], [ 0.000000e+00, %L394 ]
  %178 = call float @llvm.sqrt.f32(float %value_phi142255)
  %179 = fsub float %124, %122
  %180 = fcmp uge float %179, 0.000000e+00
  br i1 %180, label %L482, label %L480

L480:                                             ; preds = %L476
  call void @j_throw_complex_domainerror_3933(ptr nonnull @"jl_sym#sqrt#3934.jit", float %179) #16
  unreachable

L482:                                             ; preds = %L476
  %181 = fadd float %124, %122
  %182 = fcmp uge float %181, 0.000000e+00
  br i1 %182, label %L488, label %L486

L486:                                             ; preds = %L482
  call void @j_throw_complex_domainerror_3933(ptr nonnull @"jl_sym#sqrt#3934.jit", float %181) #16
  unreachable

L488:                                             ; preds = %L482
  %183 = call float @llvm.sqrt.f32(float %179)
  %184 = call float @llvm.sqrt.f32(float %181)
  %185 = fmul float %183, %184
  %186 = fmul float %124, %185
  %187 = fdiv float %178, %186
  %188 = fmul float %187, %122
  %189 = fcmp oge float %186, 0x3810000000000000
  %190 = fcmp oeq float %value_phi142255, 0.000000e+00
  %191 = fcmp oge float %187, 0x3810000000000000
  %192 = fcmp ole float %187, 0x47EFFFFFE0000000
  %narrow = and i1 %191, %192
  %193 = fcmp oge float %188, 0x3810000000000000
  %194 = fcmp ole float %188, 0x47EFFFFFE0000000
  %narrow247 = and i1 %193, %194
  %195 = and i1 %narrow, %narrow247
  %196 = or i1 %190, %195
  %197 = and i1 %189, %196
  br i1 %197, label %L511, label %L559

L511:                                             ; preds = %L488
  br i1 %narrow247, label %L521, label %L541

L521:                                             ; preds = %L511
  %198 = fneg float %188
  %.inv = fcmp ogt float %127, %198
  %199 = select i1 %.inv, float %127, float %198
  %.inv248 = fcmp olt float %199, %188
  %200 = select i1 %.inv248, float %199, float %188
  %201 = fsub float %127, %200
  %202 = fadd float %201, 0.000000e+00
  br label %L565

L541:                                             ; preds = %L511
  %gc_slot_addr_3 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3, align 8
  %203 = call float @j__exceptional_product_3936(float %187, float %122, float 1.000000e+00)
  %204 = fsub float %127, %203
  %205 = call float @llvm.maximum.f32(float %204, float 0.000000e+00)
  %206 = fadd float %127, %203
  %207 = call float @llvm.minimum.f32(float %206, float 0.000000e+00)
  %208 = fadd float %205, %207
  %209 = fcmp ult float %187, 0.000000e+00
  %210 = call float @llvm.fabs.f32(float %122)
  %211 = fcmp une float %210, 0x7FF0000000000000
  %.not251 = or i1 %211, %209
  %212 = select i1 %.not251, float %208, float 0.000000e+00
  br label %L565

L559:                                             ; preds = %L488
  store ptr %"m::SqrtLSModel.ls74.X", ptr %1, align 8
  %gc_slot_addr_3822 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3822, align 8
  %gc_slot_addr_2823 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 32
  store ptr %"m::SqrtLSModel.ls89.r", ptr %gc_slot_addr_2823, align 8
  %213 = call float @j__sqrt_cold_3937(ptr nonnull %"m::SqrtLSModel", ptr nocapture nonnull readonly %"new::SubArray", ptr nocapture nonnull readonly %1, ptr nonnull %"m::SqrtLSModel.ls89.r", ptr nocapture nonnull readonly %"m::SqrtLSModel.gt", float %110, float %value_phi61, i64 signext %value_phi9)
  br label %L565

L561:                                             ; preds = %L344
  store ptr %"m::SqrtLSModel.ls74.X", ptr %0, align 8
  %gc_slot_addr_3824 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3824, align 8
  %gc_slot_addr_2825 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 32
  store ptr %"m::SqrtLSModel.ls89.r", ptr %gc_slot_addr_2825, align 8
  %214 = call float @j__sqrt_cold_3937(ptr nonnull %"m::SqrtLSModel", ptr nocapture nonnull readonly %"new::SubArray", ptr nocapture nonnull readonly %0, ptr nonnull %"m::SqrtLSModel.ls89.r", ptr nocapture nonnull readonly %"m::SqrtLSModel.gt", float %110, float %value_phi61, i64 signext %value_phi9)
  br label %L565

L565:                                             ; preds = %L561, %L559, %L541, %L521, %L383
  %value_phi92 = phi float [ %213, %L559 ], [ %214, %L561 ], [ 0.000000e+00, %L383 ], [ %202, %L521 ], [ %212, %L541 ]
  %215 = fadd float %value_phi8, %value_phi92
  %.not252 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %216 = add nuw i64 %value_phi9, 1
  br i1 %.not252, label %L577, label %L31

L577:                                             ; preds = %L565, %L17
  %value_phi97 = phi float [ %value_phi4, %L17 ], [ %215, %L565 ]
  %.not253 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not253, label %L588, label %L17thread-pre-split

L588:                                             ; preds = %L577, %L17.preheader, %top
  %value_phi100 = phi float [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi97, %L577 ]
  %frame.prev836 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev836, ptr %tls_pgcstack, align 8
  ret float %value_phi100
}
