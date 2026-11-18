; Function Signature: pass(typeof(M_x1a.ProximalSolvers._column_dot_rsqr), typeof(M_x1a.ProximalSolvers._sqrt_minimizer), M_x1a.ProximalSolvers.SqrtLSModel{Float64, M_x1a.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
; Function Attrs: noinline
define double @julia_pass_2503(ptr noundef nonnull align 8 dereferenceable(80) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe2 = alloca [6 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 48, i1 true)
  %0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 24
  %1 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  %"new::Tuple77" = alloca { [1 x [1 x i64]], i64 }, align 8
  %"new::SubArray" = alloca [5 x i64], align 8
  %"m::SqrtLSModel.gt" = alloca i64, align 8
  %"new::Tuple165" = alloca [1 x i64], align 8
  %"new::Tuple221" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #17
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 16, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
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
  %value_phi4 = phi double [ %value_phi97, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %10 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %10, label %L577, label %L31

L31:                                              ; preds = %L565, %L17
  %value_phi8 = phi double [ %200, %L565 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %201, %L565 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %11 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %11, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple221", align 8
  %gc_slot_addr_2 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 32
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_2, align 8
  call void @j_throw_boundserror_2506(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple221") #18
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %11, 3
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %12 = load double, ptr %memoryref_data11, align 8
  %13 = fcmp ord double %12, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr167" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr167.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr167", align 8
  %14 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 1
  br i1 %13, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %14, label %L299, label %L65.preheader

L65.preheader:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %15 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %11
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check654 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 8
  br i1 %min.iters.check654, label %L71, label %vector.ph655

vector.ph655:                                     ; preds = %L65.preheader
  %n.vec657 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775800
  br label %vector.body658

vector.body658:                                   ; preds = %vector.body658, %vector.ph655
  %index659 = phi i64 [ 0, %vector.ph655 ], [ %index.next670, %vector.body658 ]
  %vec.phi660 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph655 ], [ %24, %vector.body658 ]
  %vec.phi661 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph655 ], [ %25, %vector.body658 ]
  %vec.phi662 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph655 ], [ %28, %vector.body658 ]
  %vec.phi663 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph655 ], [ %29, %vector.body658 ]
  %vec.phi664 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph655 ], [ %32, %vector.body658 ]
  %vec.phi665 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph655 ], [ %33, %vector.body658 ]
  %.reass = add i64 %index659, %15
  %16 = shl i64 %.reass, 3
  %17 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %16
  %18 = getelementptr inbounds nuw i8, ptr %17, i64 32
  %wide.load666 = load <4 x double>, ptr %17, align 8
  %wide.load667 = load <4 x double>, ptr %18, align 8
  %19 = shl i64 %index659, 3
  %20 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %19
  %21 = getelementptr inbounds nuw i8, ptr %20, i64 32
  %wide.load668 = load <4 x double>, ptr %20, align 8
  %wide.load669 = load <4 x double>, ptr %21, align 8
  %22 = fmul contract <4 x double> %wide.load666, %wide.load666
  %23 = fmul contract <4 x double> %wide.load667, %wide.load667
  %24 = fadd reassoc contract <4 x double> %vec.phi660, %22
  %25 = fadd reassoc contract <4 x double> %vec.phi661, %23
  %26 = fmul contract <4 x double> %wide.load666, %wide.load668
  %27 = fmul contract <4 x double> %wide.load667, %wide.load669
  %28 = fadd reassoc contract <4 x double> %vec.phi662, %26
  %29 = fadd reassoc contract <4 x double> %vec.phi663, %27
  %30 = fmul contract <4 x double> %wide.load668, %wide.load668
  %31 = fmul contract <4 x double> %wide.load669, %wide.load669
  %32 = fadd reassoc contract <4 x double> %vec.phi664, %30
  %33 = fadd reassoc contract <4 x double> %vec.phi665, %31
  %index.next670 = add nuw i64 %index659, 8
  %34 = icmp eq i64 %index.next670, %n.vec657
  br i1 %34, label %middle.block653, label %vector.body658

middle.block653:                                  ; preds = %vector.body658
  %bin.rdx671 = fadd reassoc contract <4 x double> %25, %24
  %35 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx671)
  %bin.rdx672 = fadd reassoc contract <4 x double> %29, %28
  %36 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx672)
  %bin.rdx673 = fadd reassoc contract <4 x double> %33, %32
  %37 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx673)
  %cmp.n674 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec657
  br i1 %cmp.n674, label %L299, label %L71

L71:                                              ; preds = %L71, %middle.block653, %L65.preheader
  %value_phi15288 = phi double [ %42, %L71 ], [ %35, %middle.block653 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi14287 = phi i64 [ %38, %L71 ], [ %n.vec657, %middle.block653 ], [ 0, %L65.preheader ]
  %value_phi13286 = phi double [ %44, %L71 ], [ %36, %middle.block653 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi12285 = phi double [ %46, %L71 ], [ %37, %middle.block653 ], [ 0.000000e+00, %L65.preheader ]
  %38 = add nuw nsw i64 %value_phi14287, 1
  %memoryref_offset32 = add i64 %15, %value_phi14287
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 3
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %39 = load double, ptr %memoryref_data38, align 8
  %memoryref_byteoffset45 = shl i64 %value_phi14287, 3
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %40 = load double, ptr %memoryref_data50, align 8
  %41 = fmul contract double %39, %39
  %42 = fadd reassoc contract double %value_phi15288, %41
  %43 = fmul contract double %39, %40
  %44 = fadd reassoc contract double %value_phi13286, %43
  %45 = fmul contract double %40, %40
  %46 = fadd reassoc contract double %value_phi12285, %45
  %exitcond.not = icmp eq i64 %38, %"m::SqrtLSModel.ls.r.size_ptr167.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %14, label %L299, label %iter.check599

iter.check599:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr184" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr184.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr184", align 8
  %47 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr184.copyload", %11
  %memoryref_data191 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data204 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check597 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 4
  br i1 %min.iters.check597, label %L190, label %vector.main.loop.iter.check601

vector.main.loop.iter.check601:                   ; preds = %iter.check599
  %min.iters.check600 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 16
  br i1 %min.iters.check600, label %vec.epilog.ph636, label %vector.ph602

vector.ph602:                                     ; preds = %vector.main.loop.iter.check601
  %n.mod.vf603 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 12
  %n.vec604 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775792
  br label %vector.body605

vector.body605:                                   ; preds = %vector.body605, %vector.ph602
  %index606 = phi i64 [ 0, %vector.ph602 ], [ %index.next623, %vector.body605 ]
  %vec.phi607 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph602 ], [ %62, %vector.body605 ]
  %vec.phi608 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %63, %vector.body605 ]
  %vec.phi609 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %64, %vector.body605 ]
  %vec.phi610 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %65, %vector.body605 ]
  %vec.phi611 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph602 ], [ %70, %vector.body605 ]
  %vec.phi612 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %71, %vector.body605 ]
  %vec.phi613 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %72, %vector.body605 ]
  %vec.phi614 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph602 ], [ %73, %vector.body605 ]
  %.reass709 = add i64 %index606, %47
  %48 = shl i64 %.reass709, 3
  %49 = getelementptr inbounds i8, ptr %memoryref_data191, i64 %48
  %50 = getelementptr inbounds nuw i8, ptr %49, i64 32
  %51 = getelementptr inbounds nuw i8, ptr %49, i64 64
  %52 = getelementptr inbounds nuw i8, ptr %49, i64 96
  %wide.load615 = load <4 x double>, ptr %49, align 8
  %wide.load616 = load <4 x double>, ptr %50, align 8
  %wide.load617 = load <4 x double>, ptr %51, align 8
  %wide.load618 = load <4 x double>, ptr %52, align 8
  %53 = shl i64 %index606, 3
  %54 = getelementptr inbounds i8, ptr %memoryref_data204, i64 %53
  %55 = getelementptr inbounds nuw i8, ptr %54, i64 32
  %56 = getelementptr inbounds nuw i8, ptr %54, i64 64
  %57 = getelementptr inbounds nuw i8, ptr %54, i64 96
  %wide.load619 = load <4 x double>, ptr %54, align 8
  %wide.load620 = load <4 x double>, ptr %55, align 8
  %wide.load621 = load <4 x double>, ptr %56, align 8
  %wide.load622 = load <4 x double>, ptr %57, align 8
  %58 = fmul contract <4 x double> %wide.load615, %wide.load619
  %59 = fmul contract <4 x double> %wide.load616, %wide.load620
  %60 = fmul contract <4 x double> %wide.load617, %wide.load621
  %61 = fmul contract <4 x double> %wide.load618, %wide.load622
  %62 = fadd reassoc contract <4 x double> %vec.phi607, %58
  %63 = fadd reassoc contract <4 x double> %vec.phi608, %59
  %64 = fadd reassoc contract <4 x double> %vec.phi609, %60
  %65 = fadd reassoc contract <4 x double> %vec.phi610, %61
  %66 = fmul contract <4 x double> %wide.load619, %wide.load619
  %67 = fmul contract <4 x double> %wide.load620, %wide.load620
  %68 = fmul contract <4 x double> %wide.load621, %wide.load621
  %69 = fmul contract <4 x double> %wide.load622, %wide.load622
  %70 = fadd reassoc contract <4 x double> %vec.phi611, %66
  %71 = fadd reassoc contract <4 x double> %vec.phi612, %67
  %72 = fadd reassoc contract <4 x double> %vec.phi613, %68
  %73 = fadd reassoc contract <4 x double> %vec.phi614, %69
  %index.next623 = add nuw i64 %index606, 16
  %74 = icmp eq i64 %index.next623, %n.vec604
  br i1 %74, label %middle.block596, label %vector.body605

middle.block596:                                  ; preds = %vector.body605
  %bin.rdx624 = fadd reassoc contract <4 x double> %63, %62
  %bin.rdx625 = fadd reassoc contract <4 x double> %64, %bin.rdx624
  %bin.rdx626 = fadd reassoc contract <4 x double> %65, %bin.rdx625
  %75 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx626)
  %bin.rdx627 = fadd reassoc contract <4 x double> %71, %70
  %bin.rdx628 = fadd reassoc contract <4 x double> %72, %bin.rdx627
  %bin.rdx629 = fadd reassoc contract <4 x double> %73, %bin.rdx628
  %76 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx629)
  %cmp.n630 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec604
  br i1 %cmp.n630, label %L299, label %vec.epilog.iter.check637

vec.epilog.iter.check637:                         ; preds = %middle.block596
  %min.epilog.iters.check639 = icmp eq i64 %n.mod.vf603, 0
  br i1 %min.epilog.iters.check639, label %L190, label %vec.epilog.ph636

vec.epilog.ph636:                                 ; preds = %vec.epilog.iter.check637, %vector.main.loop.iter.check601
  %vec.epilog.resume.val631 = phi i64 [ %n.vec604, %vec.epilog.iter.check637 ], [ 0, %vector.main.loop.iter.check601 ]
  %bc.merge.rdx632 = phi double [ %75, %vec.epilog.iter.check637 ], [ 0.000000e+00, %vector.main.loop.iter.check601 ]
  %bc.merge.rdx633 = phi double [ %76, %vec.epilog.iter.check637 ], [ 0.000000e+00, %vector.main.loop.iter.check601 ]
  %n.vec641 = and i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", 9223372036854775804
  %77 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx632, i64 0
  %78 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx633, i64 0
  br label %vec.epilog.vector.body642

vec.epilog.vector.body642:                        ; preds = %vec.epilog.vector.body642, %vec.epilog.ph636
  %index643 = phi i64 [ %vec.epilog.resume.val631, %vec.epilog.ph636 ], [ %index.next648, %vec.epilog.vector.body642 ]
  %vec.phi644 = phi <4 x double> [ %77, %vec.epilog.ph636 ], [ %82, %vec.epilog.vector.body642 ]
  %vec.phi645 = phi <4 x double> [ %78, %vec.epilog.ph636 ], [ %84, %vec.epilog.vector.body642 ]
  %.reass711 = add i64 %index643, %47
  %79 = shl i64 %.reass711, 3
  %gep = getelementptr i8, ptr %memoryref_data191, i64 %79
  %wide.load646 = load <4 x double>, ptr %gep, align 8
  %80 = shl i64 %index643, 3
  %gep713 = getelementptr i8, ptr %memoryref_data204, i64 %80
  %wide.load647 = load <4 x double>, ptr %gep713, align 8
  %81 = fmul contract <4 x double> %wide.load646, %wide.load647
  %82 = fadd reassoc contract <4 x double> %vec.phi644, %81
  %83 = fmul contract <4 x double> %wide.load647, %wide.load647
  %84 = fadd reassoc contract <4 x double> %vec.phi645, %83
  %index.next648 = add nuw i64 %index643, 4
  %85 = icmp eq i64 %index.next648, %n.vec641
  br i1 %85, label %vec.epilog.middle.block634, label %vec.epilog.vector.body642

vec.epilog.middle.block634:                       ; preds = %vec.epilog.vector.body642
  %86 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %82)
  %87 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %84)
  %cmp.n649 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr167.copyload", %n.vec641
  br i1 %cmp.n649, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block634, %vec.epilog.iter.check637, %iter.check599
  %value_phi172291 = phi i64 [ %88, %L190 ], [ %n.vec641, %vec.epilog.middle.block634 ], [ 0, %iter.check599 ], [ %n.vec604, %vec.epilog.iter.check637 ]
  %value_phi171290 = phi double [ %92, %L190 ], [ %86, %vec.epilog.middle.block634 ], [ 0.000000e+00, %iter.check599 ], [ %75, %vec.epilog.iter.check637 ]
  %value_phi170289 = phi double [ %94, %L190 ], [ %87, %vec.epilog.middle.block634 ], [ 0.000000e+00, %iter.check599 ], [ %76, %vec.epilog.iter.check637 ]
  %88 = add nuw nsw i64 %value_phi172291, 1
  %memoryref_offset193 = add i64 %47, %value_phi172291
  %memoryref_byteoffset194 = shl i64 %memoryref_offset193, 3
  %memoryref_data199 = getelementptr inbounds i8, ptr %memoryref_data191, i64 %memoryref_byteoffset194
  %89 = load double, ptr %memoryref_data199, align 8
  %memoryref_byteoffset207 = shl i64 %value_phi172291, 3
  %memoryref_data212 = getelementptr inbounds i8, ptr %memoryref_data204, i64 %memoryref_byteoffset207
  %90 = load double, ptr %memoryref_data212, align 8
  %91 = fmul contract double %89, %90
  %92 = fadd reassoc contract double %value_phi171290, %91
  %93 = fmul contract double %90, %90
  %94 = fadd reassoc contract double %value_phi170289, %93
  %exitcond476.not = icmp eq i64 %88, %"m::SqrtLSModel.ls.r.size_ptr167.copyload"
  br i1 %exitcond476.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block634, %middle.block596, %L178, %L71, %middle.block653, %L58
  %value_phi59 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %76, %middle.block596 ], [ %87, %vec.epilog.middle.block634 ], [ %37, %middle.block653 ], [ %94, %L190 ], [ %46, %L71 ]
  %value_phi60 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %75, %middle.block596 ], [ %86, %vec.epilog.middle.block634 ], [ %36, %middle.block653 ], [ %92, %L190 ], [ %44, %L71 ]
  %value_phi61 = phi double [ 0.000000e+00, %L58 ], [ %12, %L178 ], [ %12, %middle.block596 ], [ %12, %vec.epilog.middle.block634 ], [ %35, %middle.block653 ], [ %12, %L190 ], [ %42, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not235 = icmp ult i64 %11, %"xv::Array.size_ptr62.copyload"
  br i1 %.not235, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple165", align 8
  call void @j_throw_boundserror_2506(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple165") #18
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %95 = load double, ptr %memoryref_data73, align 8
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %"m::SqrtLSModel.ls74.X.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr", align 8
  %96 = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 24
  %"m::SqrtLSModel.ls74.X.size_ptr78.copyload79" = load i64, ptr %96, align 8
  %.not236.not = icmp ult i64 %11, %"m::SqrtLSModel.ls74.X.size_ptr78.copyload79"
  br i1 %.not236.not, label %L344, label %L341

L341:                                             ; preds = %L311
  %97 = getelementptr inbounds nuw i8, ptr %"new::Tuple77", i64 8
  store i64 %value_phi9, ptr %97, align 1
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %"new::Tuple77", align 1
  %gc_slot_addr_2784 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 32
  store ptr %"m::SqrtLSModel.ls74.X", ptr %gc_slot_addr_2784, align 8
  call void @j_throw_boundserror_2515(ptr nonnull %"m::SqrtLSModel.ls74.X", ptr nocapture nonnull readonly %"new::Tuple77") #18
  unreachable

L344:                                             ; preds = %L311
  %98 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", %11
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %3, align 8
  store i64 %value_phi9, ptr %4, align 8
  store i64 %98, ptr %5, align 8
  store i64 1, ptr %6, align 8
  %"m::SqrtLSModel.ls89.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls89.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls89.r_ptr" unordered, align 8
  %"m::SqrtLSModel.gt_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.gt_ptr", align 8
  store i64 %"m::SqrtLSModel.gt_ptr.copyload", ptr %"m::SqrtLSModel.gt", align 8
  %"m::SqrtLSModel.ls89.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls89.r", i64 16
  %"m::SqrtLSModel.ls89.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls89.r.size_ptr", align 8
  %99 = fsub double %value_phi61, %value_phi61
  %100 = fcmp uno double %99, 0.000000e+00
  %101 = sitofp i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload" to double
  %102 = fmul double %101, 0x350000000000000
  %103 = fcmp ugt double %102, %value_phi61
  %.not242 = or i1 %100, %103
  %104 = fsub double %value_phi59, %value_phi59
  %105 = fcmp uno double %104, 0.000000e+00
  %106 = fcmp ugt double %102, %value_phi59
  %.not245 = or i1 %105, %106
  %.not239 = or i1 %.not242, %.not245
  %107 = bitcast i64 %"m::SqrtLSModel.gt_ptr.copyload" to double
  br i1 %.not239, label %L561, label %L378

L378:                                             ; preds = %L344
  %108 = fcmp uge double %value_phi61, 0.000000e+00
  br i1 %108, label %L383, label %L381

L381:                                             ; preds = %L378
  call void @j_throw_complex_domainerror_2510(ptr nonnull @"jl_sym#sqrt#2511.jit", double %value_phi61) #18
  unreachable

L383:                                             ; preds = %L378
  %109 = call double @llvm.sqrt.f64(double %value_phi61)
  %110 = fcmp ugt double %109, %107
  br i1 %110, label %L387, label %L565

L387:                                             ; preds = %L383
  %111 = fdiv double %value_phi60, %value_phi61
  %112 = fadd double %111, %95
  %113 = fmul double %value_phi60, %111
  %114 = fsub double %value_phi59, %113
  %115 = fmul double %value_phi59, 6.250000e-02
  %116 = fcmp uge double %114, %115
  br i1 %116, label %L471, label %L394

L394:                                             ; preds = %L387
  %117 = icmp slt i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 1
  br i1 %117, label %L476, label %iter.check

iter.check:                                       ; preds = %L394
  %memoryref_data112 = load ptr, ptr %"m::SqrtLSModel.ls89.r", align 8
  %memoryref_data126 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L405, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check572 = icmp samesign ult i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 16
  br i1 %min.iters.check572, label %vector.main.loop.iter.check.vec.epilog.ph_crit_edge, label %vector.ph

vector.main.loop.iter.check.vec.epilog.ph_crit_edge: ; preds = %vector.main.loop.iter.check
  %.pre = insertelement <4 x double> poison, double %111, i64 0
  %.pre1 = shufflevector <4 x double> %.pre, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 12
  %n.vec = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %111, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %140, %vector.body ]
  %vec.phi573 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %141, %vector.body ]
  %vec.phi574 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %142, %vector.body ]
  %vec.phi575 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %143, %vector.body ]
  %118 = shl i64 %index, 3
  %119 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %118
  %120 = getelementptr inbounds nuw i8, ptr %119, i64 32
  %121 = getelementptr inbounds nuw i8, ptr %119, i64 64
  %122 = getelementptr inbounds nuw i8, ptr %119, i64 96
  %wide.load = load <4 x double>, ptr %119, align 8
  %wide.load576 = load <4 x double>, ptr %120, align 8
  %wide.load577 = load <4 x double>, ptr %121, align 8
  %wide.load578 = load <4 x double>, ptr %122, align 8
  %.reass715 = add i64 %index, %98
  %123 = shl i64 %.reass715, 3
  %124 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %123
  %125 = getelementptr inbounds nuw i8, ptr %124, i64 32
  %126 = getelementptr inbounds nuw i8, ptr %124, i64 64
  %127 = getelementptr inbounds nuw i8, ptr %124, i64 96
  %wide.load579 = load <4 x double>, ptr %124, align 8
  %wide.load580 = load <4 x double>, ptr %125, align 8
  %wide.load581 = load <4 x double>, ptr %126, align 8
  %wide.load582 = load <4 x double>, ptr %127, align 8
  %128 = fmul <4 x double> %broadcast.splat, %wide.load579
  %129 = fmul <4 x double> %broadcast.splat, %wide.load580
  %130 = fmul <4 x double> %broadcast.splat, %wide.load581
  %131 = fmul <4 x double> %broadcast.splat, %wide.load582
  %132 = fsub <4 x double> %wide.load, %128
  %133 = fsub <4 x double> %wide.load576, %129
  %134 = fsub <4 x double> %wide.load577, %130
  %135 = fsub <4 x double> %wide.load578, %131
  %136 = fmul contract <4 x double> %132, %132
  %137 = fmul contract <4 x double> %133, %133
  %138 = fmul contract <4 x double> %134, %134
  %139 = fmul contract <4 x double> %135, %135
  %140 = fadd reassoc contract <4 x double> %vec.phi, %136
  %141 = fadd reassoc contract <4 x double> %vec.phi573, %137
  %142 = fadd reassoc contract <4 x double> %vec.phi574, %138
  %143 = fadd reassoc contract <4 x double> %vec.phi575, %139
  %index.next = add nuw i64 %index, 16
  %144 = icmp eq i64 %index.next, %n.vec
  br i1 %144, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %141, %140
  %bin.rdx583 = fadd reassoc contract <4 x double> %142, %bin.rdx
  %bin.rdx584 = fadd reassoc contract <4 x double> %143, %bin.rdx583
  %145 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx584)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L471, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L405, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
  %broadcast.splat592.pre-phi = phi <4 x double> [ %.pre1, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %broadcast.splat, %vec.epilog.iter.check ]
  %vec.epilog.resume.val = phi i64 [ 0, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %n.vec, %vec.epilog.iter.check ]
  %bc.merge.rdx = phi double [ 0.000000e+00, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %145, %vec.epilog.iter.check ]
  %n.vec586 = and i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", 9223372036854775804
  %146 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx, i64 0
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index587 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next593, %vec.epilog.vector.body ]
  %vec.phi588 = phi <4 x double> [ %146, %vec.epilog.ph ], [ %152, %vec.epilog.vector.body ]
  %147 = shl i64 %index587, 3
  %gep717 = getelementptr i8, ptr %memoryref_data112, i64 %147
  %wide.load589 = load <4 x double>, ptr %gep717, align 8
  %.reass719 = add i64 %index587, %98
  %148 = shl i64 %.reass719, 3
  %gep721 = getelementptr i8, ptr %memoryref_data126, i64 %148
  %wide.load590 = load <4 x double>, ptr %gep721, align 8
  %149 = fmul <4 x double> %broadcast.splat592.pre-phi, %wide.load590
  %150 = fsub <4 x double> %wide.load589, %149
  %151 = fmul contract <4 x double> %150, %150
  %152 = fadd reassoc contract <4 x double> %vec.phi588, %151
  %index.next593 = add nuw i64 %index587, 4
  %153 = icmp eq i64 %index.next593, %n.vec586
  br i1 %153, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %154 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %152)
  %cmp.n594 = icmp eq i64 %"m::SqrtLSModel.ls89.r.size_ptr.copyload", %n.vec586
  br i1 %cmp.n594, label %L471, label %L405

L405:                                             ; preds = %L405, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi105293 = phi i64 [ %155, %L405 ], [ %n.vec586, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi104292 = phi double [ %161, %L405 ], [ %154, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %145, %vec.epilog.iter.check ]
  %155 = add nuw nsw i64 %value_phi105293, 1
  %memoryref_byteoffset115 = shl i64 %value_phi105293, 3
  %memoryref_data120 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %memoryref_byteoffset115
  %156 = load double, ptr %memoryref_data120, align 8
  %memoryref_offset128 = add i64 %value_phi105293, %98
  %memoryref_byteoffset129 = shl i64 %memoryref_offset128, 3
  %memoryref_data134 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %memoryref_byteoffset129
  %157 = load double, ptr %memoryref_data134, align 8
  %158 = fmul double %111, %157
  %159 = fsub double %156, %158
  %160 = fmul contract double %159, %159
  %161 = fadd reassoc contract double %value_phi104292, %160
  %exitcond477.not = icmp eq i64 %155, %"m::SqrtLSModel.ls89.r.size_ptr.copyload"
  br i1 %exitcond477.not, label %L471, label %L405

L471:                                             ; preds = %L405, %vec.epilog.middle.block, %middle.block, %L387
  %value_phi142 = phi double [ %114, %L387 ], [ %145, %middle.block ], [ %154, %vec.epilog.middle.block ], [ %161, %L405 ]
  %162 = fcmp uge double %value_phi142, 0.000000e+00
  br i1 %162, label %L476, label %L474

L474:                                             ; preds = %L471
  call void @j_throw_complex_domainerror_2510(ptr nonnull @"jl_sym#sqrt#2511.jit", double %value_phi142) #18
  unreachable

L476:                                             ; preds = %L471, %L394
  %value_phi142255 = phi double [ %value_phi142, %L471 ], [ 0.000000e+00, %L394 ]
  %163 = call double @llvm.sqrt.f64(double %value_phi142255)
  %164 = fsub double %109, %107
  %165 = fcmp uge double %164, 0.000000e+00
  br i1 %165, label %L482, label %L480

L480:                                             ; preds = %L476
  call void @j_throw_complex_domainerror_2510(ptr nonnull @"jl_sym#sqrt#2511.jit", double %164) #18
  unreachable

L482:                                             ; preds = %L476
  %166 = fadd double %109, %107
  %167 = fcmp uge double %166, 0.000000e+00
  br i1 %167, label %L488, label %L486

L486:                                             ; preds = %L482
  call void @j_throw_complex_domainerror_2510(ptr nonnull @"jl_sym#sqrt#2511.jit", double %166) #18
  unreachable

L488:                                             ; preds = %L482
  %168 = call double @llvm.sqrt.f64(double %164)
  %169 = call double @llvm.sqrt.f64(double %166)
  %170 = fmul double %168, %169
  %171 = fmul double %109, %170
  %172 = fdiv double %163, %171
  %173 = fmul double %172, %107
  %174 = fcmp oge double %171, 0x10000000000000
  %175 = fcmp oeq double %value_phi142255, 0.000000e+00
  %176 = fcmp oge double %172, 0x10000000000000
  %177 = fcmp ole double %172, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %176, %177
  %178 = fcmp oge double %173, 0x10000000000000
  %179 = fcmp ole double %173, 0x7FEFFFFFFFFFFFFF
  %narrow247 = and i1 %178, %179
  %180 = and i1 %narrow, %narrow247
  %181 = or i1 %175, %180
  %182 = and i1 %174, %181
  br i1 %182, label %L511, label %L559

L511:                                             ; preds = %L488
  br i1 %narrow247, label %L521, label %L541

L521:                                             ; preds = %L511
  %183 = fneg double %173
  %.inv = fcmp ogt double %112, %183
  %184 = select i1 %.inv, double %112, double %183
  %.inv248 = fcmp olt double %184, %173
  %185 = select i1 %.inv248, double %184, double %173
  %186 = fsub double %112, %185
  %187 = fadd double %186, 0.000000e+00
  br label %L565

L541:                                             ; preds = %L511
  %gc_slot_addr_3 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3, align 8
  %188 = call double @j__exceptional_product_2513(double %172, double %107, double 1.000000e+00)
  %189 = fsub double %112, %188
  %190 = call double @llvm.maximum.f64(double %189, double 0.000000e+00)
  %191 = fadd double %112, %188
  %192 = call double @llvm.minimum.f64(double %191, double 0.000000e+00)
  %193 = fadd double %190, %192
  %194 = fcmp ult double %172, 0.000000e+00
  %195 = call double @llvm.fabs.f64(double %107)
  %196 = fcmp une double %195, 0x7FF0000000000000
  %.not251 = or i1 %196, %194
  %197 = select i1 %.not251, double %193, double 0.000000e+00
  br label %L565

L559:                                             ; preds = %L488
  store ptr %"m::SqrtLSModel.ls74.X", ptr %0, align 8
  %gc_slot_addr_3785 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3785, align 8
  %gc_slot_addr_2786 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 32
  store ptr %"m::SqrtLSModel.ls89.r", ptr %gc_slot_addr_2786, align 8
  %198 = call double @j__sqrt_cold_2514(ptr nonnull %"m::SqrtLSModel", ptr nocapture nonnull readonly %"new::SubArray", ptr nocapture nonnull readonly %0, ptr nonnull %"m::SqrtLSModel.ls89.r", ptr nocapture nonnull readonly %"m::SqrtLSModel.gt", double %95, double %value_phi61, i64 signext %value_phi9)
  br label %L565

L561:                                             ; preds = %L344
  store ptr %"m::SqrtLSModel.ls74.X", ptr %1, align 8
  %gc_slot_addr_3787 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 40
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_3787, align 8
  %gc_slot_addr_2788 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 32
  store ptr %"m::SqrtLSModel.ls89.r", ptr %gc_slot_addr_2788, align 8
  %199 = call double @j__sqrt_cold_2514(ptr nonnull %"m::SqrtLSModel", ptr nocapture nonnull readonly %"new::SubArray", ptr nocapture nonnull readonly %1, ptr nonnull %"m::SqrtLSModel.ls89.r", ptr nocapture nonnull readonly %"m::SqrtLSModel.gt", double %95, double %value_phi61, i64 signext %value_phi9)
  br label %L565

L565:                                             ; preds = %L561, %L559, %L541, %L521, %L383
  %value_phi92 = phi double [ %198, %L559 ], [ %199, %L561 ], [ 0.000000e+00, %L383 ], [ %187, %L521 ], [ %197, %L541 ]
  %200 = fadd double %value_phi8, %value_phi92
  %.not252 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %201 = add nuw i64 %value_phi9, 1
  br i1 %.not252, label %L577, label %L31

L577:                                             ; preds = %L565, %L17
  %value_phi97 = phi double [ %value_phi4, %L17 ], [ %200, %L565 ]
  %.not253 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not253, label %L588, label %L17thread-pre-split

L588:                                             ; preds = %L577, %L17.preheader, %top
  %value_phi100 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi97, %L577 ]
  %frame.prev799 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev799, ptr %tls_pgcstack, align 8
  ret double %value_phi100
}
