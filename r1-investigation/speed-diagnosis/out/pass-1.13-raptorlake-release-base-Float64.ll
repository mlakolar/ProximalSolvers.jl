; Function Signature: pass(typeof(M_base.ProximalSolvers._column_dot_rsqr), typeof(M_base.ProximalSolvers._sqrt_minimizer), M_base.ProximalSolvers.SqrtLSModel{Float64, M_base.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
; Function Attrs: noinline
define double @julia_pass_1551(ptr noundef nonnull align 8 dereferenceable(80) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe2 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe2, i8 0, i64 24, i1 true)
  %"new::Tuple159" = alloca [1 x i64], align 8
  %"new::Tuple215" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #17
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe2, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe2, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe2, ptr %tls_pgcstack, align 8
  %".reps::Int64" = call i64 @llvm.smax.i64(i64 %"reps::Int64", i64 0)
  %0 = icmp slt i64 %"reps::Int64", 1
  br i1 %0, label %L604, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %"m::SqrtLSModel.ls" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"xv::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"xv::Array", i64 16
  %"m::SqrtLSModel.ls.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 24
  %"m::SqrtLSModel.ls.a_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 32
  %"m::SqrtLSModel.gt_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel", i64 8
  %1 = load i64, ptr %"xv::Array.size_ptr", align 8
  %2 = icmp slt i64 %1, 1
  br i1 %2, label %L604, label %L17

L17thread-pre-split:                              ; preds = %L593
  %3 = add nuw i64 %value_phi3, 1
  %"xv::Array.size_ptr.copyload.pr" = load i64, ptr %"xv::Array.size_ptr", align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %"xv::Array.size_ptr.copyload" = phi i64 [ %"xv::Array.size_ptr.copyload.pr", %L17thread-pre-split ], [ %1, %L17.preheader ]
  %value_phi3 = phi i64 [ %3, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi double [ %value_phi82, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %4 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %4, label %L593, label %L31

L31:                                              ; preds = %L580, %L17
  %value_phi8 = phi double [ %181, %L580 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %182, %L580 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %5 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %5, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple215", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_0, align 8
  call void @j_throw_boundserror_1554(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple215") #18
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %5, 3
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %6 = load double, ptr %memoryref_data11, align 8
  %7 = fcmp ord double %6, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr161" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr161.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr161", align 8
  %8 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 1
  br i1 %7, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %8, label %L299, label %L65.preheader

L65.preheader:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %9 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %5
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check502 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 8
  br i1 %min.iters.check502, label %L71, label %vector.ph503

vector.ph503:                                     ; preds = %L65.preheader
  %n.vec505 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775800
  br label %vector.body506

vector.body506:                                   ; preds = %vector.body506, %vector.ph503
  %index507 = phi i64 [ 0, %vector.ph503 ], [ %index.next518, %vector.body506 ]
  %vec.phi508 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph503 ], [ %18, %vector.body506 ]
  %vec.phi509 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph503 ], [ %19, %vector.body506 ]
  %vec.phi510 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph503 ], [ %22, %vector.body506 ]
  %vec.phi511 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph503 ], [ %23, %vector.body506 ]
  %vec.phi512 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph503 ], [ %26, %vector.body506 ]
  %vec.phi513 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph503 ], [ %27, %vector.body506 ]
  %.reass = add i64 %index507, %9
  %10 = shl i64 %.reass, 3
  %11 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %10
  %12 = getelementptr inbounds nuw i8, ptr %11, i64 32
  %wide.load514 = load <4 x double>, ptr %11, align 8
  %wide.load515 = load <4 x double>, ptr %12, align 8
  %13 = shl i64 %index507, 3
  %14 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %13
  %15 = getelementptr inbounds nuw i8, ptr %14, i64 32
  %wide.load516 = load <4 x double>, ptr %14, align 8
  %wide.load517 = load <4 x double>, ptr %15, align 8
  %16 = fmul contract <4 x double> %wide.load514, %wide.load514
  %17 = fmul contract <4 x double> %wide.load515, %wide.load515
  %18 = fadd reassoc contract <4 x double> %vec.phi508, %16
  %19 = fadd reassoc contract <4 x double> %vec.phi509, %17
  %20 = fmul contract <4 x double> %wide.load514, %wide.load516
  %21 = fmul contract <4 x double> %wide.load515, %wide.load517
  %22 = fadd reassoc contract <4 x double> %vec.phi510, %20
  %23 = fadd reassoc contract <4 x double> %vec.phi511, %21
  %24 = fmul contract <4 x double> %wide.load516, %wide.load516
  %25 = fmul contract <4 x double> %wide.load517, %wide.load517
  %26 = fadd reassoc contract <4 x double> %vec.phi512, %24
  %27 = fadd reassoc contract <4 x double> %vec.phi513, %25
  %index.next518 = add nuw i64 %index507, 8
  %28 = icmp eq i64 %index.next518, %n.vec505
  br i1 %28, label %middle.block501, label %vector.body506

middle.block501:                                  ; preds = %vector.body506
  %bin.rdx519 = fadd reassoc contract <4 x double> %19, %18
  %29 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx519)
  %bin.rdx520 = fadd reassoc contract <4 x double> %23, %22
  %30 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx520)
  %bin.rdx521 = fadd reassoc contract <4 x double> %27, %26
  %31 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx521)
  %cmp.n522 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec505
  br i1 %cmp.n522, label %L299, label %L71

L71:                                              ; preds = %L71, %middle.block501, %L65.preheader
  %value_phi15284 = phi double [ %36, %L71 ], [ %29, %middle.block501 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi14283 = phi i64 [ %32, %L71 ], [ %n.vec505, %middle.block501 ], [ 0, %L65.preheader ]
  %value_phi13282 = phi double [ %38, %L71 ], [ %30, %middle.block501 ], [ 0.000000e+00, %L65.preheader ]
  %value_phi12281 = phi double [ %40, %L71 ], [ %31, %middle.block501 ], [ 0.000000e+00, %L65.preheader ]
  %32 = add nuw nsw i64 %value_phi14283, 1
  %memoryref_offset32 = add i64 %9, %value_phi14283
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 3
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %33 = load double, ptr %memoryref_data38, align 8
  %memoryref_byteoffset45 = shl i64 %value_phi14283, 3
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %34 = load double, ptr %memoryref_data50, align 8
  %35 = fmul contract double %33, %33
  %36 = fadd reassoc contract double %value_phi15284, %35
  %37 = fmul contract double %33, %34
  %38 = fadd reassoc contract double %value_phi13282, %37
  %39 = fmul contract double %34, %34
  %40 = fadd reassoc contract double %value_phi12281, %39
  %exitcond.not = icmp eq i64 %32, %"m::SqrtLSModel.ls.r.size_ptr161.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %8, label %L299, label %iter.check447

iter.check447:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr178" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr178.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr178", align 8
  %41 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr178.copyload", %5
  %memoryref_data185 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data198 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check445 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 4
  br i1 %min.iters.check445, label %L190, label %vector.main.loop.iter.check449

vector.main.loop.iter.check449:                   ; preds = %iter.check447
  %min.iters.check448 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 16
  br i1 %min.iters.check448, label %vec.epilog.ph484, label %vector.ph450

vector.ph450:                                     ; preds = %vector.main.loop.iter.check449
  %n.mod.vf451 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 12
  %n.vec452 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775792
  br label %vector.body453

vector.body453:                                   ; preds = %vector.body453, %vector.ph450
  %index454 = phi i64 [ 0, %vector.ph450 ], [ %index.next471, %vector.body453 ]
  %vec.phi455 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph450 ], [ %56, %vector.body453 ]
  %vec.phi456 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %57, %vector.body453 ]
  %vec.phi457 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %58, %vector.body453 ]
  %vec.phi458 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %59, %vector.body453 ]
  %vec.phi459 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph450 ], [ %64, %vector.body453 ]
  %vec.phi460 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %65, %vector.body453 ]
  %vec.phi461 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %66, %vector.body453 ]
  %vec.phi462 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph450 ], [ %67, %vector.body453 ]
  %.reass557 = add i64 %index454, %41
  %42 = shl i64 %.reass557, 3
  %43 = getelementptr inbounds i8, ptr %memoryref_data185, i64 %42
  %44 = getelementptr inbounds nuw i8, ptr %43, i64 32
  %45 = getelementptr inbounds nuw i8, ptr %43, i64 64
  %46 = getelementptr inbounds nuw i8, ptr %43, i64 96
  %wide.load463 = load <4 x double>, ptr %43, align 8
  %wide.load464 = load <4 x double>, ptr %44, align 8
  %wide.load465 = load <4 x double>, ptr %45, align 8
  %wide.load466 = load <4 x double>, ptr %46, align 8
  %47 = shl i64 %index454, 3
  %48 = getelementptr inbounds i8, ptr %memoryref_data198, i64 %47
  %49 = getelementptr inbounds nuw i8, ptr %48, i64 32
  %50 = getelementptr inbounds nuw i8, ptr %48, i64 64
  %51 = getelementptr inbounds nuw i8, ptr %48, i64 96
  %wide.load467 = load <4 x double>, ptr %48, align 8
  %wide.load468 = load <4 x double>, ptr %49, align 8
  %wide.load469 = load <4 x double>, ptr %50, align 8
  %wide.load470 = load <4 x double>, ptr %51, align 8
  %52 = fmul contract <4 x double> %wide.load463, %wide.load467
  %53 = fmul contract <4 x double> %wide.load464, %wide.load468
  %54 = fmul contract <4 x double> %wide.load465, %wide.load469
  %55 = fmul contract <4 x double> %wide.load466, %wide.load470
  %56 = fadd reassoc contract <4 x double> %vec.phi455, %52
  %57 = fadd reassoc contract <4 x double> %vec.phi456, %53
  %58 = fadd reassoc contract <4 x double> %vec.phi457, %54
  %59 = fadd reassoc contract <4 x double> %vec.phi458, %55
  %60 = fmul contract <4 x double> %wide.load467, %wide.load467
  %61 = fmul contract <4 x double> %wide.load468, %wide.load468
  %62 = fmul contract <4 x double> %wide.load469, %wide.load469
  %63 = fmul contract <4 x double> %wide.load470, %wide.load470
  %64 = fadd reassoc contract <4 x double> %vec.phi459, %60
  %65 = fadd reassoc contract <4 x double> %vec.phi460, %61
  %66 = fadd reassoc contract <4 x double> %vec.phi461, %62
  %67 = fadd reassoc contract <4 x double> %vec.phi462, %63
  %index.next471 = add nuw i64 %index454, 16
  %68 = icmp eq i64 %index.next471, %n.vec452
  br i1 %68, label %middle.block444, label %vector.body453

middle.block444:                                  ; preds = %vector.body453
  %bin.rdx472 = fadd reassoc contract <4 x double> %57, %56
  %bin.rdx473 = fadd reassoc contract <4 x double> %58, %bin.rdx472
  %bin.rdx474 = fadd reassoc contract <4 x double> %59, %bin.rdx473
  %69 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx474)
  %bin.rdx475 = fadd reassoc contract <4 x double> %65, %64
  %bin.rdx476 = fadd reassoc contract <4 x double> %66, %bin.rdx475
  %bin.rdx477 = fadd reassoc contract <4 x double> %67, %bin.rdx476
  %70 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx477)
  %cmp.n478 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec452
  br i1 %cmp.n478, label %L299, label %vec.epilog.iter.check485

vec.epilog.iter.check485:                         ; preds = %middle.block444
  %min.epilog.iters.check487 = icmp eq i64 %n.mod.vf451, 0
  br i1 %min.epilog.iters.check487, label %L190, label %vec.epilog.ph484

vec.epilog.ph484:                                 ; preds = %vec.epilog.iter.check485, %vector.main.loop.iter.check449
  %vec.epilog.resume.val479 = phi i64 [ %n.vec452, %vec.epilog.iter.check485 ], [ 0, %vector.main.loop.iter.check449 ]
  %bc.merge.rdx480 = phi double [ %69, %vec.epilog.iter.check485 ], [ 0.000000e+00, %vector.main.loop.iter.check449 ]
  %bc.merge.rdx481 = phi double [ %70, %vec.epilog.iter.check485 ], [ 0.000000e+00, %vector.main.loop.iter.check449 ]
  %n.vec489 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775804
  %71 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx480, i64 0
  %72 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx481, i64 0
  br label %vec.epilog.vector.body490

vec.epilog.vector.body490:                        ; preds = %vec.epilog.vector.body490, %vec.epilog.ph484
  %index491 = phi i64 [ %vec.epilog.resume.val479, %vec.epilog.ph484 ], [ %index.next496, %vec.epilog.vector.body490 ]
  %vec.phi492 = phi <4 x double> [ %71, %vec.epilog.ph484 ], [ %76, %vec.epilog.vector.body490 ]
  %vec.phi493 = phi <4 x double> [ %72, %vec.epilog.ph484 ], [ %78, %vec.epilog.vector.body490 ]
  %.reass559 = add i64 %index491, %41
  %73 = shl i64 %.reass559, 3
  %gep = getelementptr i8, ptr %memoryref_data185, i64 %73
  %wide.load494 = load <4 x double>, ptr %gep, align 8
  %74 = shl i64 %index491, 3
  %gep561 = getelementptr i8, ptr %memoryref_data198, i64 %74
  %wide.load495 = load <4 x double>, ptr %gep561, align 8
  %75 = fmul contract <4 x double> %wide.load494, %wide.load495
  %76 = fadd reassoc contract <4 x double> %vec.phi492, %75
  %77 = fmul contract <4 x double> %wide.load495, %wide.load495
  %78 = fadd reassoc contract <4 x double> %vec.phi493, %77
  %index.next496 = add nuw i64 %index491, 4
  %79 = icmp eq i64 %index.next496, %n.vec489
  br i1 %79, label %vec.epilog.middle.block482, label %vec.epilog.vector.body490

vec.epilog.middle.block482:                       ; preds = %vec.epilog.vector.body490
  %80 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %76)
  %81 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %78)
  %cmp.n497 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec489
  br i1 %cmp.n497, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block482, %vec.epilog.iter.check485, %iter.check447
  %value_phi166287 = phi i64 [ %82, %L190 ], [ %n.vec489, %vec.epilog.middle.block482 ], [ 0, %iter.check447 ], [ %n.vec452, %vec.epilog.iter.check485 ]
  %value_phi165286 = phi double [ %86, %L190 ], [ %80, %vec.epilog.middle.block482 ], [ 0.000000e+00, %iter.check447 ], [ %69, %vec.epilog.iter.check485 ]
  %value_phi164285 = phi double [ %88, %L190 ], [ %81, %vec.epilog.middle.block482 ], [ 0.000000e+00, %iter.check447 ], [ %70, %vec.epilog.iter.check485 ]
  %82 = add nuw nsw i64 %value_phi166287, 1
  %memoryref_offset187 = add i64 %41, %value_phi166287
  %memoryref_byteoffset188 = shl i64 %memoryref_offset187, 3
  %memoryref_data193 = getelementptr inbounds i8, ptr %memoryref_data185, i64 %memoryref_byteoffset188
  %83 = load double, ptr %memoryref_data193, align 8
  %memoryref_byteoffset201 = shl i64 %value_phi166287, 3
  %memoryref_data206 = getelementptr inbounds i8, ptr %memoryref_data198, i64 %memoryref_byteoffset201
  %84 = load double, ptr %memoryref_data206, align 8
  %85 = fmul contract double %83, %84
  %86 = fadd reassoc contract double %value_phi165286, %85
  %87 = fmul contract double %84, %84
  %88 = fadd reassoc contract double %value_phi164285, %87
  %exitcond352.not = icmp eq i64 %82, %"m::SqrtLSModel.ls.r.size_ptr161.copyload"
  br i1 %exitcond352.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block482, %middle.block444, %L178, %L71, %middle.block501, %L58
  %value_phi59 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %70, %middle.block444 ], [ %81, %vec.epilog.middle.block482 ], [ %31, %middle.block501 ], [ %88, %L190 ], [ %40, %L71 ]
  %value_phi60 = phi double [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %69, %middle.block444 ], [ %80, %vec.epilog.middle.block482 ], [ %30, %middle.block501 ], [ %86, %L190 ], [ %38, %L71 ]
  %value_phi61 = phi double [ 0.000000e+00, %L58 ], [ %6, %L178 ], [ %6, %middle.block444 ], [ %6, %vec.epilog.middle.block482 ], [ %29, %middle.block501 ], [ %6, %L190 ], [ %36, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not229 = icmp ult i64 %5, %"xv::Array.size_ptr62.copyload"
  br i1 %.not229, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple159", align 8
  call void @j_throw_boundserror_1554(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple159") #18
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %89 = load double, ptr %memoryref_data73, align 8
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls74.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls74.r_ptr" unordered, align 8
  %"m::SqrtLSModel.ls74.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.r", i64 16
  %"m::SqrtLSModel.ls74.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.r.size_ptr", align 8
  %90 = fsub double %value_phi61, %value_phi61
  %91 = fcmp uno double %90, 0.000000e+00
  %92 = sitofp i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload" to double
  %93 = fmul double %92, 0x350000000000000
  %94 = fcmp ugt double %93, %value_phi61
  %.not235 = or i1 %91, %94
  %95 = fsub double %value_phi59, %value_phi59
  %96 = fcmp uno double %95, 0.000000e+00
  %97 = fcmp ugt double %93, %value_phi59
  %.not238 = or i1 %96, %97
  %.not232 = or i1 %.not235, %.not238
  br i1 %.not232, label %L578, label %L337

L337:                                             ; preds = %L311
  %98 = fcmp uge double %value_phi61, 0.000000e+00
  br i1 %98, label %L343, label %L341

L341:                                             ; preds = %L337
  call void @j_throw_complex_domainerror_1558(ptr nonnull @"jl_sym#sqrt#1559.jit", double %value_phi61) #18
  unreachable

L343:                                             ; preds = %L337
  %"m::SqrtLSModel.gt_ptr.copyload239" = load double, ptr %"m::SqrtLSModel.gt_ptr", align 8
  %99 = call double @llvm.sqrt.f64(double %value_phi61)
  %100 = fcmp ugt double %99, %"m::SqrtLSModel.gt_ptr.copyload239"
  br i1 %100, label %L348, label %L580

L348:                                             ; preds = %L343
  %101 = fdiv double %value_phi60, %value_phi61
  %102 = fadd double %101, %89
  %103 = fmul double %value_phi60, %101
  %104 = fsub double %value_phi59, %103
  %105 = fmul double %value_phi59, 6.250000e-02
  %106 = fcmp uge double %104, %105
  br i1 %106, label %L483, label %L355

L355:                                             ; preds = %L348
  %107 = icmp slt i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 1
  br i1 %107, label %L471, label %iter.check

iter.check:                                       ; preds = %L355
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %memoryref_data97 = load ptr, ptr %"m::SqrtLSModel.ls74.r", align 8
  %"m::SqrtLSModel.ls74.X.size_ptr112" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr112.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr112", align 8
  %108 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr112.copyload", %5
  %memoryref_data118 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L368, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check420 = icmp samesign ult i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 16
  br i1 %min.iters.check420, label %vector.main.loop.iter.check.vec.epilog.ph_crit_edge, label %vector.ph

vector.main.loop.iter.check.vec.epilog.ph_crit_edge: ; preds = %vector.main.loop.iter.check
  %.pre = insertelement <4 x double> poison, double %101, i64 0
  %.pre1 = shufflevector <4 x double> %.pre, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 12
  %n.vec = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %101, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %131, %vector.body ]
  %vec.phi421 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %132, %vector.body ]
  %vec.phi422 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %133, %vector.body ]
  %vec.phi423 = phi <4 x double> [ splat (double -0.000000e+00), %vector.ph ], [ %134, %vector.body ]
  %109 = shl i64 %index, 3
  %110 = getelementptr inbounds i8, ptr %memoryref_data97, i64 %109
  %111 = getelementptr inbounds nuw i8, ptr %110, i64 32
  %112 = getelementptr inbounds nuw i8, ptr %110, i64 64
  %113 = getelementptr inbounds nuw i8, ptr %110, i64 96
  %wide.load = load <4 x double>, ptr %110, align 8
  %wide.load424 = load <4 x double>, ptr %111, align 8
  %wide.load425 = load <4 x double>, ptr %112, align 8
  %wide.load426 = load <4 x double>, ptr %113, align 8
  %.reass563 = add i64 %index, %108
  %114 = shl i64 %.reass563, 3
  %115 = getelementptr inbounds i8, ptr %memoryref_data118, i64 %114
  %116 = getelementptr inbounds nuw i8, ptr %115, i64 32
  %117 = getelementptr inbounds nuw i8, ptr %115, i64 64
  %118 = getelementptr inbounds nuw i8, ptr %115, i64 96
  %wide.load427 = load <4 x double>, ptr %115, align 8
  %wide.load428 = load <4 x double>, ptr %116, align 8
  %wide.load429 = load <4 x double>, ptr %117, align 8
  %wide.load430 = load <4 x double>, ptr %118, align 8
  %119 = fmul <4 x double> %broadcast.splat, %wide.load427
  %120 = fmul <4 x double> %broadcast.splat, %wide.load428
  %121 = fmul <4 x double> %broadcast.splat, %wide.load429
  %122 = fmul <4 x double> %broadcast.splat, %wide.load430
  %123 = fsub <4 x double> %wide.load, %119
  %124 = fsub <4 x double> %wide.load424, %120
  %125 = fsub <4 x double> %wide.load425, %121
  %126 = fsub <4 x double> %wide.load426, %122
  %127 = fmul contract <4 x double> %123, %123
  %128 = fmul contract <4 x double> %124, %124
  %129 = fmul contract <4 x double> %125, %125
  %130 = fmul contract <4 x double> %126, %126
  %131 = fadd reassoc contract <4 x double> %vec.phi, %127
  %132 = fadd reassoc contract <4 x double> %vec.phi421, %128
  %133 = fadd reassoc contract <4 x double> %vec.phi422, %129
  %134 = fadd reassoc contract <4 x double> %vec.phi423, %130
  %index.next = add nuw i64 %index, 16
  %135 = icmp eq i64 %index.next, %n.vec
  br i1 %135, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %132, %131
  %bin.rdx431 = fadd reassoc contract <4 x double> %133, %bin.rdx
  %bin.rdx432 = fadd reassoc contract <4 x double> %134, %bin.rdx431
  %136 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx432)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L471, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L368, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
  %broadcast.splat440.pre-phi = phi <4 x double> [ %.pre1, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %broadcast.splat, %vec.epilog.iter.check ]
  %vec.epilog.resume.val = phi i64 [ 0, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %n.vec, %vec.epilog.iter.check ]
  %bc.merge.rdx = phi double [ 0.000000e+00, %vector.main.loop.iter.check.vec.epilog.ph_crit_edge ], [ %136, %vec.epilog.iter.check ]
  %n.vec434 = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 9223372036854775804
  %137 = insertelement <4 x double> <double poison, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, double %bc.merge.rdx, i64 0
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index435 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next441, %vec.epilog.vector.body ]
  %vec.phi436 = phi <4 x double> [ %137, %vec.epilog.ph ], [ %143, %vec.epilog.vector.body ]
  %138 = shl i64 %index435, 3
  %gep565 = getelementptr i8, ptr %memoryref_data97, i64 %138
  %wide.load437 = load <4 x double>, ptr %gep565, align 8
  %.reass567 = add i64 %index435, %108
  %139 = shl i64 %.reass567, 3
  %gep569 = getelementptr i8, ptr %memoryref_data118, i64 %139
  %wide.load438 = load <4 x double>, ptr %gep569, align 8
  %140 = fmul <4 x double> %broadcast.splat440.pre-phi, %wide.load438
  %141 = fsub <4 x double> %wide.load437, %140
  %142 = fmul contract <4 x double> %141, %141
  %143 = fadd reassoc contract <4 x double> %vec.phi436, %142
  %index.next441 = add nuw i64 %index435, 4
  %144 = icmp eq i64 %index.next441, %n.vec434
  br i1 %144, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %145 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %143)
  %cmp.n442 = icmp eq i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", %n.vec434
  br i1 %cmp.n442, label %L471, label %L368

L368:                                             ; preds = %L368, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi90289 = phi i64 [ %146, %L368 ], [ %n.vec434, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi89288 = phi double [ %152, %L368 ], [ %145, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %136, %vec.epilog.iter.check ]
  %146 = add nuw nsw i64 %value_phi90289, 1
  %memoryref_byteoffset100 = shl i64 %value_phi90289, 3
  %memoryref_data105 = getelementptr inbounds i8, ptr %memoryref_data97, i64 %memoryref_byteoffset100
  %147 = load double, ptr %memoryref_data105, align 8
  %memoryref_offset120 = add i64 %108, %value_phi90289
  %memoryref_byteoffset121 = shl i64 %memoryref_offset120, 3
  %memoryref_data126 = getelementptr inbounds i8, ptr %memoryref_data118, i64 %memoryref_byteoffset121
  %148 = load double, ptr %memoryref_data126, align 8
  %149 = fmul double %101, %148
  %150 = fsub double %147, %149
  %151 = fmul contract double %150, %150
  %152 = fadd reassoc contract double %value_phi89288, %151
  %exitcond353.not = icmp eq i64 %146, %"m::SqrtLSModel.ls74.r.size_ptr.copyload"
  br i1 %exitcond353.not, label %L471, label %L368

L471:                                             ; preds = %L368, %vec.epilog.middle.block, %middle.block, %L355
  %value_phi133 = phi double [ 0.000000e+00, %L355 ], [ %136, %middle.block ], [ %145, %vec.epilog.middle.block ], [ %152, %L368 ]
  %153 = fsub double %value_phi133, %value_phi133
  %154 = fcmp uno double %153, 0.000000e+00
  %155 = fcmp ugt double %93, %value_phi133
  %.not243 = or i1 %155, %154
  br i1 %.not243, label %L481, label %L483

L481:                                             ; preds = %L471
  %gc_slot_addr_0621 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0621, align 8
  %156 = call double @j__sqrt_offrange_step_1562(ptr nonnull %"m::SqrtLSModel", double %89, i64 signext %value_phi9)
  br label %L580

L483:                                             ; preds = %L471, %L348
  %value_phi135 = phi double [ %104, %L348 ], [ %value_phi133, %L471 ]
  %157 = fcmp uge double %value_phi135, 0.000000e+00
  br i1 %157, label %L488, label %L486

L486:                                             ; preds = %L483
  call void @j_throw_complex_domainerror_1558(ptr nonnull @"jl_sym#sqrt#1559.jit", double %value_phi135) #18
  unreachable

L488:                                             ; preds = %L483
  %158 = call double @llvm.sqrt.f64(double %value_phi135)
  %159 = fsub double %99, %"m::SqrtLSModel.gt_ptr.copyload239"
  %160 = fcmp uge double %159, 0.000000e+00
  br i1 %160, label %L495, label %L493

L493:                                             ; preds = %L488
  call void @j_throw_complex_domainerror_1558(ptr nonnull @"jl_sym#sqrt#1559.jit", double %159) #18
  unreachable

L495:                                             ; preds = %L488
  %161 = fadd double %99, %"m::SqrtLSModel.gt_ptr.copyload239"
  %162 = fcmp uge double %161, 0.000000e+00
  br i1 %162, label %L502, label %L500

L500:                                             ; preds = %L495
  call void @j_throw_complex_domainerror_1558(ptr nonnull @"jl_sym#sqrt#1559.jit", double %161) #18
  unreachable

L502:                                             ; preds = %L495
  %163 = call double @llvm.sqrt.f64(double %159)
  %164 = call double @llvm.sqrt.f64(double %161)
  %165 = fmul double %163, %164
  %166 = fmul double %99, %165
  %167 = fdiv double %158, %166
  %168 = fmul double %"m::SqrtLSModel.gt_ptr.copyload239", %167
  %169 = fcmp ult double %166, 0x10000000000000
  %170 = fcmp ult double %167, 0x10000000000000
  %171 = fcmp ugt double %167, 0x7FEFFFFFFFFFFFFF
  %narrow.not251 = or i1 %170, %171
  %.not248 = or i1 %169, %narrow.not251
  %172 = fcmp ult double %168, 0x10000000000000
  %173 = fcmp ugt double %168, 0x7FEFFFFFFFFFFFFF
  %narrow244.not254 = or i1 %172, %173
  %.not246 = or i1 %.not248, %narrow244.not254
  br i1 %.not246, label %L576, label %L535

L535:                                             ; preds = %L502
  %174 = fneg double %168
  %.inv = fcmp ogt double %102, %174
  %175 = select i1 %.inv, double %102, double %174
  %.inv255 = fcmp olt double %175, %168
  %176 = select i1 %.inv255, double %175, double %168
  %177 = fsub double %102, %176
  %178 = fadd double %177, 0.000000e+00
  br label %L580

L576:                                             ; preds = %L502
  %gc_slot_addr_0622 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0622, align 8
  %179 = call double @j__sqrt_band_step_1561(double %102, double %99, double %"m::SqrtLSModel.gt_ptr.copyload239", double %158, i64 signext 0)
  br label %L580

L578:                                             ; preds = %L311
  %gc_slot_addr_0623 = getelementptr inbounds nuw i8, ptr %gcframe2, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0623, align 8
  %180 = call double @j__sqrt_offrange_step_1562(ptr nonnull %"m::SqrtLSModel", double %89, i64 signext %value_phi9)
  br label %L580

L580:                                             ; preds = %L578, %L576, %L535, %L481, %L343
  %value_phi77 = phi double [ %156, %L481 ], [ %179, %L576 ], [ %180, %L578 ], [ 0.000000e+00, %L343 ], [ %178, %L535 ]
  %181 = fadd double %value_phi8, %value_phi77
  %.not256 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %182 = add nuw i64 %value_phi9, 1
  br i1 %.not256, label %L593, label %L31

L593:                                             ; preds = %L580, %L17
  %value_phi82 = phi double [ %value_phi4, %L17 ], [ %181, %L580 ]
  %.not257 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not257, label %L604, label %L17thread-pre-split

L604:                                             ; preds = %L593, %L17.preheader, %top
  %value_phi85 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi82, %L593 ]
  %frame.prev631 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev631, ptr %tls_pgcstack, align 8
  ret double %value_phi85
}
