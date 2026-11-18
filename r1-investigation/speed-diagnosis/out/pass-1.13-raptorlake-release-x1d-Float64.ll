; Function Signature: pass(typeof(M_x1d.ProximalSolvers._column_dot_rsqr), typeof(M_x1d.ProximalSolvers._sqrt_minimizer), M_x1d.ProximalSolvers.SqrtLSModel{Float64, M_x1d.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
; Function Attrs: noinline
define double @julia_pass_2138(ptr noundef nonnull align 8 dereferenceable(80) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe2 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 24, i1 true)
  %"new::Tuple89" = alloca { [1 x [1 x i64]], i64 }, align 8
  %"new::Tuple153" = alloca [1 x i64], align 8
  %"new::Tuple209" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #16
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
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
  %value_phi4 = phi double [ %value_phi83, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %4 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %4, label %L522, label %L31

L31:                                              ; preds = %L510, %L17
  %value_phi8 = phi double [ %173, %L510 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %174, %L510 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %5 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %5, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple209", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_0, align 8
  call void @j_throw_boundserror_2141(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple209") #17
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %5, 3
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %6 = load double, ptr %memoryref_data11, align 8
  %7 = fcmp ord double %6, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr155" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr155.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr155", align 8
  %8 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 1
  br i1 %7, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %8, label %L299, label %L65.preheader

L65.preheader:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %9 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %5
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check616 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 8
  br i1 %min.iters.check616, label %L71, label %vector.ph617

vector.ph617:                                     ; preds = %L65.preheader
  %n.vec619 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775800
  br label %vector.body620

vector.body620:                                   ; preds = %vector.body620, %vector.ph617
  %index621 = phi i64 [ 0, %vector.ph617 ], [ %index.next632, %vector.body620 ]
  %vec.phi622 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph617 ], [ %18, %vector.body620 ]
  %vec.phi623 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph617 ], [ %19, %vector.body620 ]
  %vec.phi624 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph617 ], [ %22, %vector.body620 ]
  %vec.phi625 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph617 ], [ %23, %vector.body620 ]
  %vec.phi626 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph617 ], [ %26, %vector.body620 ]
  %vec.phi627 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph617 ], [ %27, %vector.body620 ]
  %.reass = add i64 %index621, %9
  %10 = shl i64 %.reass, 3
  %11 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %10
  %12 = getelementptr inbounds nuw i8, ptr %11, i64 32
  %wide.load628 = load <4 x double>, ptr %11, align 8
  %wide.load629 = load <4 x double>, ptr %12, align 8
  %13 = shl i64 %index621, 3
  %14 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %13
  %15 = getelementptr inbounds nuw i8, ptr %14, i64 32
  %wide.load630 = load <4 x double>, ptr %14, align 8
  %wide.load631 = load <4 x double>, ptr %15, align 8
  %16 = fmul contract <4 x double> %wide.load628, %wide.load628
  %17 = fmul contract <4 x double> %wide.load629, %wide.load629
  %18 = fadd reassoc contract <4 x double> %vec.phi622, %16
  %19 = fadd reassoc contract <4 x double> %vec.phi623, %17
  %20 = fmul contract <4 x double> %wide.load628, %wide.load630
  %21 = fmul contract <4 x double> %wide.load629, %wide.load631
  %22 = fadd reassoc contract <4 x double> %vec.phi624, %20
  %23 = fadd reassoc contract <4 x double> %vec.phi625, %21
  %24 = fmul contract <4 x double> %wide.load630, %wide.load630
  %25 = fmul contract <4 x double> %wide.load631, %wide.load631
  %26 = fadd reassoc contract <4 x double> %vec.phi626, %24
  %27 = fadd reassoc contract <4 x double> %vec.phi627, %25
  %index.next632 = add nuw i64 %index621, 8
  %28 = icmp eq i64 %index.next632, %n.vec619
  br i1 %28, label %middle.block615, label %vector.body620

middle.block615:                                  ; preds = %vector.body620
  %bin.rdx633 = fadd reassoc contract <4 x double> %19, %18
  %29 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx633)
  %bin.rdx634 = fadd reassoc contract <4 x double> %23, %22
  %30 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx634)
  %bin.rdx635 = fadd reassoc contract <4 x double> %27, %26
  %31 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx635)
  %cmp.n636 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec619
  br i1 %cmp.n636, label %L299, label %L71

L71:                                              ; preds = %L71, %middle.block615, %L65.preheader
  %value_phi15272 = phi double [ %36, %L71 ], [ %29, %middle.block615 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi14271 = phi i64 [ %32, %L71 ], [ %n.vec619, %middle.block615 ], [ 0, %L65.preheader ]
  %value_phi13270 = phi double [ %38, %L71 ], [ %30, %middle.block615 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi12269 = phi double [ %40, %L71 ], [ %31, %middle.block615 ], [ 0.000000e+00, %L65.preheader ]
  %32 = add nuw nsw i64 %value_phi14271, 1
  %memoryref_offset32 = add i64 %9, %value_phi14271
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 3
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %33 = load double, ptr %memoryref_data38, align 8
  %memoryref_byteoffset45 = shl i64 %value_phi14271, 3
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %34 = load double, ptr %memoryref_data50, align 8
  %35 = fmul contract double %33, %33
  %36 = fadd reassoc contract double %value_phi15272, %35
  %37 = fmul contract double %33, %34
  %38 = fadd reassoc contract double %value_phi13270, %37
  %39 = fmul contract double %34, %34
  %40 = fadd reassoc contract double %value_phi12269, %39
  %exitcond.not = icmp eq i64 %32, %"m::SqrtLSModel.ls.r.size_ptr155.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %8, label %L299, label %iter.check561

iter.check561:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr172" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr172.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr172", align 8
  %41 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr172.copyload", %5
  %memoryref_data179 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data192 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check559 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 4
  br i1 %min.iters.check559, label %L190, label %vector.main.loop.iter.check563

vector.main.loop.iter.check563:                   ; preds = %iter.check561
  %min.iters.check562 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 16
  br i1 %min.iters.check562, label %vec.epilog.ph598, label %vector.ph564

vector.ph564:                                     ; preds = %vector.main.loop.iter.check563
  %n.mod.vf565 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 12
  %n.vec566 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775792
  br label %vector.body567

vector.body567:                                   ; preds = %vector.body567, %vector.ph564
  %index568 = phi i64 [ 0, %vector.ph564 ], [ %index.next585, %vector.body567 ]
  %vec.phi569 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph564 ], [ %56, %vector.body567 ]
  %vec.phi570 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %57, %vector.body567 ]
  %vec.phi571 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %58, %vector.body567 ]
  %vec.phi572 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %59, %vector.body567 ]
  %vec.phi573 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph564 ], [ %64, %vector.body567 ]
  %vec.phi574 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %65, %vector.body567 ]
  %vec.phi575 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %66, %vector.body567 ]
  %vec.phi576 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph564 ], [ %67, %vector.body567 ]
  %.reass671 = add i64 %index568, %41
  %42 = shl i64 %.reass671, 3
  %43 = getelementptr inbounds i8, ptr %memoryref_data179, i64 %42
  %44 = getelementptr inbounds nuw i8, ptr %43, i64 32
  %45 = getelementptr inbounds nuw i8, ptr %43, i64 64
  %46 = getelementptr inbounds nuw i8, ptr %43, i64 96
  %wide.load577 = load <4 x double>, ptr %43, align 8
  %wide.load578 = load <4 x double>, ptr %44, align 8
  %wide.load579 = load <4 x double>, ptr %45, align 8
  %wide.load580 = load <4 x double>, ptr %46, align 8
  %47 = shl i64 %index568, 3
  %48 = getelementptr inbounds i8, ptr %memoryref_data192, i64 %47
  %49 = getelementptr inbounds nuw i8, ptr %48, i64 32
  %50 = getelementptr inbounds nuw i8, ptr %48, i64 64
  %51 = getelementptr inbounds nuw i8, ptr %48, i64 96
  %wide.load581 = load <4 x double>, ptr %48, align 8
  %wide.load582 = load <4 x double>, ptr %49, align 8
  %wide.load583 = load <4 x double>, ptr %50, align 8
  %wide.load584 = load <4 x double>, ptr %51, align 8
  %52 = fmul contract <4 x double> %wide.load577, %wide.load581
  %53 = fmul contract <4 x double> %wide.load578, %wide.load582
  %54 = fmul contract <4 x double> %wide.load579, %wide.load583
  %55 = fmul contract <4 x double> %wide.load580, %wide.load584
  %56 = fadd reassoc contract <4 x double> %vec.phi569, %52
  %57 = fadd reassoc contract <4 x double> %vec.phi570, %53
  %58 = fadd reassoc contract <4 x double> %vec.phi571, %54
  %59 = fadd reassoc contract <4 x double> %vec.phi572, %55
  %60 = fmul contract <4 x double> %wide.load581, %wide.load581
  %61 = fmul contract <4 x double> %wide.load582, %wide.load582
  %62 = fmul contract <4 x double> %wide.load583, %wide.load583
  %63 = fmul contract <4 x double> %wide.load584, %wide.load584
  %64 = fadd reassoc contract <4 x double> %vec.phi573, %60
  %65 = fadd reassoc contract <4 x double> %vec.phi574, %61
  %66 = fadd reassoc contract <4 x double> %vec.phi575, %62
  %67 = fadd reassoc contract <4 x double> %vec.phi576, %63
  %index.next585 = add nuw i64 %index568, 16
  %68 = icmp eq i64 %index.next585, %n.vec566
  br i1 %68, label %middle.block558, label %vector.body567

middle.block558:                                  ; preds = %vector.body567
  %bin.rdx586 = fadd reassoc contract <4 x double> %57, %56
  %bin.rdx587 = fadd reassoc contract <4 x double> %58, %bin.rdx586
  %bin.rdx588 = fadd reassoc contract <4 x double> %59, %bin.rdx587
  %69 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx588)
  %bin.rdx589 = fadd reassoc contract <4 x double> %65, %64
  %bin.rdx590 = fadd reassoc contract <4 x double> %66, %bin.rdx589
  %bin.rdx591 = fadd reassoc contract <4 x double> %67, %bin.rdx590
  %70 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx591)
  %cmp.n592 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec566
  br i1 %cmp.n592, label %L299, label %vec.epilog.iter.check599

vec.epilog.iter.check599:                         ; preds = %middle.block558
  %min.epilog.iters.check601 = icmp eq i64 %n.mod.vf565, 0
  br i1 %min.epilog.iters.check601, label %L190, label %vec.epilog.ph598

vec.epilog.ph598:                                 ; preds = %vec.epilog.iter.check599, %vector.main.loop.iter.check563
  %vec.epilog.resume.val593 = phi i64 [ %n.vec566, %vec.epilog.iter.check599 ], [ 0, %vector.main.loop.iter.check563 ]
  %bc.merge.rdx594 = phi double [ %69, %vec.epilog.iter.check599 ], [ 0.000000e+00, %vector.main.loop.iter.check563 ]
  %bc.merge.rdx595 = phi double [ %70, %vec.epilog.iter.check599 ], [ 0.000000e+00, %vector.main.loop.iter.check563 ]
  %n.vec603 = and i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", 9223372036854775804
  %71 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx594, i64 0
  %72 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx595, i64 0
  br label %vec.epilog.vector.body604

vec.epilog.vector.body604:                        ; preds = %vec.epilog.vector.body604, %vec.epilog.ph598
  %index605 = phi i64 [ %vec.epilog.resume.val593, %vec.epilog.ph598 ], [ %index.next610, %vec.epilog.vector.body604 ]
  %vec.phi606 = phi <4 x double> [ %71, %vec.epilog.ph598 ], [ %76, %vec.epilog.vector.body604 ]
  %vec.phi607 = phi <4 x double> [ %72, %vec.epilog.ph598 ], [ %78, %vec.epilog.vector.body604 ]
  %.reass673 = add i64 %index605, %41
  %73 = shl i64 %.reass673, 3
  %gep = getelementptr i8, ptr %memoryref_data179, i64 %73
  %wide.load608 = load <4 x double>, ptr %gep, align 8
  %74 = shl i64 %index605, 3
  %gep675 = getelementptr i8, ptr %memoryref_data192, i64 %74
  %wide.load609 = load <4 x double>, ptr %gep675, align 8
  %75 = fmul contract <4 x double> %wide.load608, %wide.load609
  %76 = fadd reassoc contract <4 x double> %vec.phi606, %75
  %77 = fmul contract <4 x double> %wide.load609, %wide.load609
  %78 = fadd reassoc contract <4 x double> %vec.phi607, %77
  %index.next610 = add nuw i64 %index605, 4
  %79 = icmp eq i64 %index.next610, %n.vec603
  br i1 %79, label %vec.epilog.middle.block596, label %vec.epilog.vector.body604

vec.epilog.middle.block596:                       ; preds = %vec.epilog.vector.body604
  %80 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %76)
  %81 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %78)
  %cmp.n611 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr155.copyload", %n.vec603
  br i1 %cmp.n611, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block596, %vec.epilog.iter.check599, %iter.check561
  %value_phi160275 = phi i64 [ %82, %L190 ], [ %n.vec603, %vec.epilog.middle.block596 ], [ 0, %iter.check561 ], [ %n.vec566, %vec.epilog.iter.check599 ]
  %value_phi159274 = phi double [ %86, %L190 ], [ %80, %vec.epilog.middle.block596 ], [ 0.000000e+00, %iter.check561 ], [ %69, %vec.epilog.iter.check599 ]
  %value_phi158273 = phi double [ %88, %L190 ], [ %81, %vec.epilog.middle.block596 ], [ 0.000000e+00, %iter.check561 ], [ %70, %vec.epilog.iter.check599 ]
  %82 = add nuw nsw i64 %value_phi160275, 1
  %memoryref_offset181 = add i64 %41, %value_phi160275
  %memoryref_byteoffset182 = shl i64 %memoryref_offset181, 3
  %memoryref_data187 = getelementptr inbounds i8, ptr %memoryref_data179, i64 %memoryref_byteoffset182
  %83 = load double, ptr %memoryref_data187, align 8
  %memoryref_byteoffset195 = shl i64 %value_phi160275, 3
  %memoryref_data200 = getelementptr inbounds i8, ptr %memoryref_data192, i64 %memoryref_byteoffset195
  %84 = load double, ptr %memoryref_data200, align 8
  %85 = fmul contract double %83, %84
  %86 = fadd reassoc contract double %value_phi159274, %85
  %87 = fmul contract double %84, %84
  %88 = fadd reassoc contract double %value_phi158273, %87
  %exitcond454.not = icmp eq i64 %82, %"m::SqrtLSModel.ls.r.size_ptr155.copyload"
  br i1 %exitcond454.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block596, %middle.block558, %L178, %L71, %middle.block615, %L58
  %value_phi59 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %70, %middle.block558 ], [ %81, %vec.epilog.middle.block596 ], [ %31, %middle.block615 ], [ %88, %L190 ], [ %40, %L71 ]
  %value_phi60 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %69, %middle.block558 ], [ %80, %vec.epilog.middle.block596 ], [ %30, %middle.block615 ], [ %86, %L190 ], [ %38, %L71 ]
  %value_phi61 = phi double [ 0.000000e+00, %L58 ], [ %6, %L178 ], [ %6, %middle.block558 ], [ %6, %vec.epilog.middle.block596 ], [ %29, %middle.block615 ], [ %6, %L190 ], [ %36, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not223 = icmp ult i64 %5, %"xv::Array.size_ptr62.copyload"
  br i1 %.not223, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple153", align 8
  call void @j_throw_boundserror_2141(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple153") #17
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %89 = load double, ptr %memoryref_data73, align 8
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %"m::SqrtLSModel.ls75.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls75.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls75.r_ptr" unordered, align 8
  %"m::SqrtLSModel.gt_ptr.copyload224" = load double, ptr %"m::SqrtLSModel.gt_ptr", align 8
  %"m::SqrtLSModel.ls75.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls75.r", i64 16
  %"m::SqrtLSModel.ls75.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls75.r.size_ptr", align 8
  %90 = fsub double %value_phi61, %value_phi61
  %91 = fcmp uno double %90, 0.000000e+00
  %92 = sitofp i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload" to double
  %93 = fmul double %92, 0x350000000000000
  %94 = fcmp ugt double %93, %value_phi61
  %.not230 = or i1 %91, %94
  %95 = fsub double %value_phi59, %value_phi59
  %96 = fcmp uno double %95, 0.000000e+00
  %97 = fcmp ugt double %93, %value_phi59
  %.not233 = or i1 %96, %97
  %.not227 = or i1 %.not230, %.not233
  br i1 %.not227, label %L506, label %L341

L341:                                             ; preds = %L311
  %98 = fcmp uge double %value_phi61, 0.000000e+00
  br i1 %98, label %L345, label %L343

L343:                                             ; preds = %L341
  call void @j_throw_complex_domainerror_2145(ptr nonnull @"jl_sym#sqrt#2146.jit", double %value_phi61) #17
  unreachable

L345:                                             ; preds = %L341
  %99 = call double @llvm.sqrt.f64(double %value_phi61)
  %100 = fcmp ugt double %99, %"m::SqrtLSModel.gt_ptr.copyload224"
  br i1 %100, label %L350, label %L510

L350:                                             ; preds = %L345
  %101 = fdiv double %value_phi60, %value_phi61
  %102 = fmul double %value_phi60, %101
  %103 = fsub double %value_phi59, %102
  %104 = fmul double %value_phi59, 6.250000e-02
  %105 = fcmp uge double %103, %104
  br i1 %105, label %L474, label %L356

L356:                                             ; preds = %L350
  %"m::SqrtLSModel.ls74.X.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr", align 8
  %106 = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 24
  %"m::SqrtLSModel.ls74.X.size_ptr90.copyload91" = load i64, ptr %106, align 8
  %.not234.not = icmp ult i64 %5, %"m::SqrtLSModel.ls74.X.size_ptr90.copyload91"
  br i1 %.not234.not, label %L383, label %L380

L380:                                             ; preds = %L356
  %107 = getelementptr inbounds nuw i8, ptr %"new::Tuple89", i64 8
  store i64 %value_phi9, ptr %107, align 1
  store i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", ptr %"new::Tuple89", align 1
  %gc_slot_addr_0741 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls74.X", ptr %gc_slot_addr_0741, align 8
  call void @j_throw_boundserror_2148(ptr nonnull %"m::SqrtLSModel.ls74.X", ptr nocapture nonnull readonly %"new::Tuple89") #17
  unreachable

L383:                                             ; preds = %L356
  %108 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr.copyload", %5
  %109 = icmp slt i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 1
  br i1 %109, label %L481, label %iter.check

iter.check:                                       ; preds = %L383
  %memoryref_data112 = load ptr, ptr %"m::SqrtLSModel.ls75.r", align 8
  %memoryref_data126 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L406, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check534 = icmp samesign ult i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 16
  br i1 %min.iters.check534, label %vector.main.loop.iter.check.vec.epilog.ph_crit_edge, label %vector.ph

vector.main.loop.iter.check.vec.epilog.ph_crit_edge: ; preds = %vector.main.loop.iter.check
  %.pre = insertelement <4 x double> poison, double %101, i64 0
  %.pre1 = shufflevector <4 x double> %.pre, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 12
  %n.vec = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %101, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %132, %vector.body ]
  %vec.phi535 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %133, %vector.body ]
  %vec.phi536 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %134, %vector.body ]
  %vec.phi537 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %135, %vector.body ]
  %110 = shl i64 %index, 3
  %111 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %110
  %112 = getelementptr inbounds nuw i8, ptr %111, i64 32
  %113 = getelementptr inbounds nuw i8, ptr %111, i64 64
  %114 = getelementptr inbounds nuw i8, ptr %111, i64 96
  %wide.load = load <4 x double>, ptr %111, align 8
  %wide.load538 = load <4 x double>, ptr %112, align 8
  %wide.load539 = load <4 x double>, ptr %113, align 8
  %wide.load540 = load <4 x double>, ptr %114, align 8
  %.reass677 = add i64 %index, %108
  %115 = shl i64 %.reass677, 3
  %116 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %115
  %117 = getelementptr inbounds nuw i8, ptr %116, i64 32
  %118 = getelementptr inbounds nuw i8, ptr %116, i64 64
  %119 = getelementptr inbounds nuw i8, ptr %116, i64 96
  %wide.load541 = load <4 x double>, ptr %116, align 8
  %wide.load542 = load <4 x double>, ptr %117, align 8
  %wide.load543 = load <4 x double>, ptr %118, align 8
  %wide.load544 = load <4 x double>, ptr %119, align 8
  %120 = fmul <4 x double> %broadcast.splat, %wide.load541
  %121 = fmul <4 x double> %broadcast.splat, %wide.load542
  %122 = fmul <4 x double> %broadcast.splat, %wide.load543
  %123 = fmul <4 x double> %broadcast.splat, %wide.load544
  %124 = fsub <4 x double> %wide.load, %120
  %125 = fsub <4 x double> %wide.load538, %121
  %126 = fsub <4 x double> %wide.load539, %122
  %127 = fsub <4 x double> %wide.load540, %123
  %128 = fmul contract <4 x double> %124, %124
  %129 = fmul contract <4 x double> %125, %125
  %130 = fmul contract <4 x double> %126, %126
  %131 = fmul contract <4 x double> %127, %127
  %132 = fadd reassoc contract <4 x double> %vec.phi, %128
  %133 = fadd reassoc contract <4 x double> %vec.phi535, %129
  %134 = fadd reassoc contract <4 x double> %vec.phi536, %130
  %135 = fadd reassoc contract <4 x double> %vec.phi537, %131
  %index.next = add nuw i64 %index, 16
  %136 = icmp eq i64 %index.next, %n.vec
  br i1 %136, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %133, %132
  %bin.rdx545 = fadd reassoc contract <4 x double> %134, %bin.rdx
  %bin.rdx546 = fadd reassoc contract <4 x double> %135, %bin.rdx545
  %137 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx546)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L474, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L406, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
  %broadcast.splat554.pre-phi = phi <4 x double> [ %.pre1, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %broadcast.splat, %vec.epilog.iter.check ]
  %vec.epilog.resume.val = phi i64 [ 0, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %n.vec, %vec.epilog.iter.check ]
  %bc.merge.rdx = phi double [ 0.000000e+00, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %137, %vec.epilog.iter.check ]
  %n.vec548 = and i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", 9223372036854775804
  %138 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx, i64 0
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index549 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next555, %vec.epilog.vector.body ]
  %vec.phi550 = phi <4 x double> [ %138, %vec.epilog.ph ], [ %144, %vec.epilog.vector.body ]
  %139 = shl i64 %index549, 3
  %gep679 = getelementptr i8, ptr %memoryref_data112, i64 %139
  %wide.load551 = load <4 x double>, ptr %gep679, align 8
  %.reass681 = add i64 %index549, %108
  %140 = shl i64 %.reass681, 3
  %gep683 = getelementptr i8, ptr %memoryref_data126, i64 %140
  %wide.load552 = load <4 x double>, ptr %gep683, align 8
  %141 = fmul <4 x double> %broadcast.splat554.pre-phi, %wide.load552
  %142 = fsub <4 x double> %wide.load551, %141
  %143 = fmul contract <4 x double> %142, %142
  %144 = fadd reassoc contract <4 x double> %vec.phi550, %143
  %index.next555 = add nuw i64 %index549, 4
  %145 = icmp eq i64 %index.next555, %n.vec548
  br i1 %145, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %146 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %144)
  %cmp.n556 = icmp eq i64 %"m::SqrtLSModel.ls75.r.size_ptr.copyload", %n.vec548
  br i1 %cmp.n556, label %L474, label %L406

L406:                                             ; preds = %L406, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi105277 = phi i64 [ %147, %L406 ], [ %n.vec548, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi104276 = phi double [ %153, %L406 ], [ %146, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %137, %vec.epilog.iter.check ]
  %147 = add nuw nsw i64 %value_phi105277, 1
  %memoryref_byteoffset115 = shl i64 %value_phi105277, 3
  %memoryref_data120 = getelementptr inbounds i8, ptr %memoryref_data112, i64 %memoryref_byteoffset115
  %148 = load double, ptr %memoryref_data120, align 8
  %memoryref_offset128 = add i64 %value_phi105277, %108
  %memoryref_byteoffset129 = shl i64 %memoryref_offset128, 3
  %memoryref_data134 = getelementptr inbounds i8, ptr %memoryref_data126, i64 %memoryref_byteoffset129
  %149 = load double, ptr %memoryref_data134, align 8
  %150 = fmul double %101, %149
  %151 = fsub double %148, %150
  %152 = fmul contract double %151, %151
  %153 = fadd reassoc contract double %value_phi104276, %152
  %exitcond455.not = icmp eq i64 %147, %"m::SqrtLSModel.ls75.r.size_ptr.copyload"
  br i1 %exitcond455.not, label %L474, label %L406

L474:                                             ; preds = %L406, %vec.epilog.middle.block, %middle.block, %L350
  %value_phi142 = phi double [ %103, %L350 ], [ %137, %middle.block ], [ %146, %vec.epilog.middle.block ], [ %153, %L406 ]
  %154 = fcmp uge double %value_phi142, 0.000000e+00
  br i1 %154, label %L481, label %L479

L479:                                             ; preds = %L474
  call void @j_throw_complex_domainerror_2145(ptr nonnull @"jl_sym#sqrt#2146.jit", double %value_phi142) #17
  unreachable

L481:                                             ; preds = %L474, %L383
  %value_phi142239 = phi double [ %value_phi142, %L474 ], [ 0.000000e+00, %L383 ]
  %155 = fadd double %101, %89
  %156 = fdiv double %"m::SqrtLSModel.gt_ptr.copyload224", %99
  %157 = call double @llvm.sqrt.f64(double %value_phi142239)
  %158 = fsub double %99, %"m::SqrtLSModel.gt_ptr.copyload224"
  %159 = fcmp uge double %158, 0.000000e+00
  br i1 %159, label %L488, label %L486

L486:                                             ; preds = %L481
  call void @j_throw_complex_domainerror_2145(ptr nonnull @"jl_sym#sqrt#2146.jit", double %158) #17
  unreachable

L488:                                             ; preds = %L481
  %160 = fadd double %99, %"m::SqrtLSModel.gt_ptr.copyload224"
  %161 = fcmp uge double %160, 0.000000e+00
  br i1 %161, label %L495, label %L493

L493:                                             ; preds = %L488
  call void @j_throw_complex_domainerror_2145(ptr nonnull @"jl_sym#sqrt#2146.jit", double %160) #17
  unreachable

L495:                                             ; preds = %L488
  %162 = call double @llvm.sqrt.f64(double %158)
  %163 = call double @llvm.sqrt.f64(double %160)
  %164 = fmul double %162, %163
  %165 = fdiv double %157, %164
  %166 = fmul double %156, %165
  %167 = fsub double %155, %166
  %168 = call double @llvm.maximum.f64(double %167, double 0.000000e+00)
  %169 = fadd double %155, %166
  %170 = call double @llvm.minimum.f64(double %169, double 0.000000e+00)
  %171 = fadd double %168, %170
  br label %L510

L506:                                             ; preds = %L311
  %gc_slot_addr_0742 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0742, align 8
  %172 = call double @j__sqrt_cold_2149(ptr nonnull %"m::SqrtLSModel", double %89, double %value_phi61, i64 signext %value_phi9)
  br label %L510

L510:                                             ; preds = %L506, %L495, %L345
  %value_phi78 = phi double [ %171, %L495 ], [ %172, %L506 ], [ 0.000000e+00, %L345 ]
  %173 = fadd double %value_phi8, %value_phi78
  %.not236 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %174 = add nuw i64 %value_phi9, 1
  br i1 %.not236, label %L522, label %L31

L522:                                             ; preds = %L510, %L17
  %value_phi83 = phi double [ %value_phi4, %L17 ], [ %173, %L510 ]
  %.not237 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not237, label %L533, label %L17thread-pre-split

L533:                                             ; preds = %L522, %L17.preheader, %top
  %value_phi86 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi83, %L522 ]
  %frame.prev749 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev749, ptr %tls_pgcstack, align 8
  ret double %value_phi86
}
