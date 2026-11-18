; Function Signature: pass(typeof(M_base.ProximalSolvers._column_dot_rsqr), typeof(M_base.ProximalSolvers._sqrt_minimizer), M_base.ProximalSolvers.SqrtLSModel{Float32, M_base.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
; Function Attrs: noinline
define float @julia_pass_3142(ptr noundef nonnull align 8 dereferenceable(72) %"m::SqrtLSModel", ptr noundef nonnull align 8 dereferenceable(24) %"xv::Array", i64 signext %"reps::Int64") local_unnamed_addr #0 {
top:
  %gcframe1 = alloca [3 x ptr], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %gcframe1, i8 0, i64 24, i1 true)
  %"new::Tuple159" = alloca [1 x i64], align 8
  %"new::Tuple215" = alloca [1 x i64], align 8
  %thread_ptr = call ptr asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr inbounds i8, ptr %thread_ptr, i64 -8
  %tls_pgcstack = load ptr, ptr %tls_ppgcstack, align 8
  store i64 4, ptr %gcframe1, align 8
  %frame.prev = getelementptr inbounds nuw i8, ptr %gcframe1, i64 8
  %task.gcstack = load ptr, ptr %tls_pgcstack, align 8
  store ptr %task.gcstack, ptr %frame.prev, align 8
  store ptr %gcframe1, ptr %tls_pgcstack, align 8
  %".reps::Int64" = call i64 @llvm.smax.i64(i64 %"reps::Int64", i64 0)
  %0 = icmp slt i64 %"reps::Int64", 1
  br i1 %0, label %L605, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %"m::SqrtLSModel.ls" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"xv::Array.size_ptr" = getelementptr inbounds nuw i8, ptr %"xv::Array", i64 16
  %"m::SqrtLSModel.ls.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 24
  %"m::SqrtLSModel.ls.a_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls", i64 32
  %"m::SqrtLSModel.gt_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel", i64 8
  %1 = load i64, ptr %"xv::Array.size_ptr", align 8
  %2 = icmp slt i64 %1, 1
  br i1 %2, label %L605, label %L17

L17thread-pre-split:                              ; preds = %L594
  %3 = add nuw i64 %value_phi3, 1
  %"xv::Array.size_ptr.copyload.pr" = load i64, ptr %"xv::Array.size_ptr", align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %"xv::Array.size_ptr.copyload" = phi i64 [ %"xv::Array.size_ptr.copyload.pr", %L17thread-pre-split ], [ %1, %L17.preheader ]
  %value_phi3 = phi i64 [ %3, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi82, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %4 = icmp slt i64 %"xv::Array.size_ptr.copyload", 1
  br i1 %4, label %L594, label %L31

L31:                                              ; preds = %L581, %L17
  %value_phi8 = phi float [ %197, %L581 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %198, %L581 ], [ 1, %L17 ]
  %"m::SqrtLSModel.ls.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls" unordered, align 8
  %"m::SqrtLSModel.ls.a" = load atomic ptr, ptr %"m::SqrtLSModel.ls.a_ptr" unordered, align 8
  %5 = add nsw i64 %value_phi9, -1
  %"m::SqrtLSModel.ls.a.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.a", i64 16
  %"m::SqrtLSModel.ls.a.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls.a.size_ptr", align 8
  %.not = icmp ult i64 %5, %"m::SqrtLSModel.ls.a.size_ptr.copyload"
  br i1 %.not, label %L51, label %L47

L47:                                              ; preds = %L31
  store i64 %value_phi9, ptr %"new::Tuple215", align 8
  %gc_slot_addr_0 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls.a", ptr %gc_slot_addr_0, align 8
  call void @j_throw_boundserror_3144(ptr nonnull %"m::SqrtLSModel.ls.a", ptr nocapture nonnull readonly %"new::Tuple215") #16
  unreachable

L51:                                              ; preds = %L31
  %"m::SqrtLSModel.ls.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls.r_ptr" unordered, align 8
  %memoryref_data = load ptr, ptr %"m::SqrtLSModel.ls.a", align 8
  %memoryref_byteoffset = shl i64 %5, 2
  %memoryref_data11 = getelementptr inbounds i8, ptr %memoryref_data, i64 %memoryref_byteoffset
  %6 = load float, ptr %memoryref_data11, align 4
  %7 = fcmp ord float %6, 0.000000e+00
  %"m::SqrtLSModel.ls.r.size_ptr161" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.r", i64 16
  %"m::SqrtLSModel.ls.r.size_ptr161.copyload" = load i64, ptr %"m::SqrtLSModel.ls.r.size_ptr161", align 8
  %8 = icmp slt i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 1
  br i1 %7, label %L178, label %L58

L58:                                              ; preds = %L51
  br i1 %8, label %L299, label %iter.check504

iter.check504:                                    ; preds = %L58
  %"m::SqrtLSModel.ls.X.size_ptr24" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr24.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr24", align 8
  %9 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr24.copyload", %5
  %memoryref_data30 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data42 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check502 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 4
  br i1 %min.iters.check502, label %L71, label %vector.main.loop.iter.check506

vector.main.loop.iter.check506:                   ; preds = %iter.check504
  %min.iters.check505 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 16
  br i1 %min.iters.check505, label %vec.epilog.ph533, label %vector.ph507

vector.ph507:                                     ; preds = %vector.main.loop.iter.check506
  %n.mod.vf508 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 12
  %n.vec509 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775792
  br label %vector.body510

vector.body510:                                   ; preds = %vector.body510, %vector.ph507
  %index511 = phi i64 [ 0, %vector.ph507 ], [ %index.next522, %vector.body510 ]
  %vec.phi512 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph507 ], [ %18, %vector.body510 ]
  %vec.phi513 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph507 ], [ %19, %vector.body510 ]
  %vec.phi514 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph507 ], [ %22, %vector.body510 ]
  %vec.phi515 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph507 ], [ %23, %vector.body510 ]
  %vec.phi516 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph507 ], [ %26, %vector.body510 ]
  %vec.phi517 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph507 ], [ %27, %vector.body510 ]
  %.reass = add i64 %index511, %9
  %10 = shl i64 %.reass, 2
  %11 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %10
  %12 = getelementptr inbounds nuw i8, ptr %11, i64 32
  %wide.load518 = load <8 x float>, ptr %11, align 4
  %wide.load519 = load <8 x float>, ptr %12, align 4
  %13 = shl i64 %index511, 2
  %14 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %13
  %15 = getelementptr inbounds nuw i8, ptr %14, i64 32
  %wide.load520 = load <8 x float>, ptr %14, align 4
  %wide.load521 = load <8 x float>, ptr %15, align 4
  %16 = fmul contract <8 x float> %wide.load518, %wide.load518
  %17 = fmul contract <8 x float> %wide.load519, %wide.load519
  %18 = fadd reassoc contract <8 x float> %vec.phi512, %16
  %19 = fadd reassoc contract <8 x float> %vec.phi513, %17
  %20 = fmul contract <8 x float> %wide.load518, %wide.load520
  %21 = fmul contract <8 x float> %wide.load519, %wide.load521
  %22 = fadd reassoc contract <8 x float> %vec.phi514, %20
  %23 = fadd reassoc contract <8 x float> %vec.phi515, %21
  %24 = fmul contract <8 x float> %wide.load520, %wide.load520
  %25 = fmul contract <8 x float> %wide.load521, %wide.load521
  %26 = fadd reassoc contract <8 x float> %vec.phi516, %24
  %27 = fadd reassoc contract <8 x float> %vec.phi517, %25
  %index.next522 = add nuw i64 %index511, 16
  %28 = icmp eq i64 %index.next522, %n.vec509
  br i1 %28, label %middle.block501, label %vector.body510

middle.block501:                                  ; preds = %vector.body510
  %bin.rdx523 = fadd reassoc contract <8 x float> %19, %18
  %29 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx523)
  %bin.rdx524 = fadd reassoc contract <8 x float> %23, %22
  %30 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx524)
  %bin.rdx525 = fadd reassoc contract <8 x float> %27, %26
  %31 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx525)
  %cmp.n526 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec509
  br i1 %cmp.n526, label %L299, label %vec.epilog.iter.check534

vec.epilog.iter.check534:                         ; preds = %middle.block501
  %min.epilog.iters.check536 = icmp eq i64 %n.mod.vf508, 0
  br i1 %min.epilog.iters.check536, label %L71, label %vec.epilog.ph533

vec.epilog.ph533:                                 ; preds = %vec.epilog.iter.check534, %vector.main.loop.iter.check506
  %vec.epilog.resume.val527 = phi i64 [ %n.vec509, %vec.epilog.iter.check534 ], [ 0, %vector.main.loop.iter.check506 ]
  %bc.merge.rdx528 = phi float [ %29, %vec.epilog.iter.check534 ], [ 0.000000e+00, %vector.main.loop.iter.check506 ]
  %bc.merge.rdx529 = phi float [ %30, %vec.epilog.iter.check534 ], [ 0.000000e+00, %vector.main.loop.iter.check506 ]
  %bc.merge.rdx530 = phi float [ %31, %vec.epilog.iter.check534 ], [ 0.000000e+00, %vector.main.loop.iter.check506 ]
  %n.vec538 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775804
  %32 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx528, i64 0
  %33 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx529, i64 0
  %34 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx530, i64 0
  br label %vec.epilog.vector.body539

vec.epilog.vector.body539:                        ; preds = %vec.epilog.vector.body539, %vec.epilog.ph533
  %index540 = phi i64 [ %vec.epilog.resume.val527, %vec.epilog.ph533 ], [ %index.next546, %vec.epilog.vector.body539 ]
  %vec.phi541 = phi <4 x float> [ %32, %vec.epilog.ph533 ], [ %38, %vec.epilog.vector.body539 ]
  %vec.phi542 = phi <4 x float> [ %33, %vec.epilog.ph533 ], [ %40, %vec.epilog.vector.body539 ]
  %vec.phi543 = phi <4 x float> [ %34, %vec.epilog.ph533 ], [ %42, %vec.epilog.vector.body539 ]
  %.reass585 = add i64 %index540, %9
  %35 = shl i64 %.reass585, 2
  %gep = getelementptr i8, ptr %memoryref_data30, i64 %35
  %wide.load544 = load <4 x float>, ptr %gep, align 4
  %36 = shl i64 %index540, 2
  %gep587 = getelementptr i8, ptr %memoryref_data42, i64 %36
  %wide.load545 = load <4 x float>, ptr %gep587, align 4
  %37 = fmul contract <4 x float> %wide.load544, %wide.load544
  %38 = fadd reassoc contract <4 x float> %vec.phi541, %37
  %39 = fmul contract <4 x float> %wide.load544, %wide.load545
  %40 = fadd reassoc contract <4 x float> %vec.phi542, %39
  %41 = fmul contract <4 x float> %wide.load545, %wide.load545
  %42 = fadd reassoc contract <4 x float> %vec.phi543, %41
  %index.next546 = add nuw i64 %index540, 4
  %43 = icmp eq i64 %index.next546, %n.vec538
  br i1 %43, label %vec.epilog.middle.block531, label %vec.epilog.vector.body539

vec.epilog.middle.block531:                       ; preds = %vec.epilog.vector.body539
  %44 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %38)
  %45 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %40)
  %46 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %42)
  %cmp.n547 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec538
  br i1 %cmp.n547, label %L299, label %L71

L71:                                              ; preds = %L71, %vec.epilog.middle.block531, %vec.epilog.iter.check534, %iter.check504
  %value_phi15284 = phi float [ %51, %L71 ], [ %44, %vec.epilog.middle.block531 ], [ 0.000000e+00, %iter.check504 ], [ %29, %vec.epilog.iter.check534 ]
  %value_phi14283 = phi i64 [ %47, %L71 ], [ %n.vec538, %vec.epilog.middle.block531 ], [ 0, %iter.check504 ], [ %n.vec509, %vec.epilog.iter.check534 ]
  %value_phi13282 = phi float [ %53, %L71 ], [ %45, %vec.epilog.middle.block531 ], [ 0.000000e+00, %iter.check504 ], [ %30, %vec.epilog.iter.check534 ]
  %value_phi12281 = phi float [ %55, %L71 ], [ %46, %vec.epilog.middle.block531 ], [ 0.000000e+00, %iter.check504 ], [ %31, %vec.epilog.iter.check534 ]
  %47 = add nuw nsw i64 %value_phi14283, 1
  %memoryref_offset32 = add i64 %9, %value_phi14283
  %memoryref_byteoffset33 = shl i64 %memoryref_offset32, 2
  %memoryref_data38 = getelementptr inbounds i8, ptr %memoryref_data30, i64 %memoryref_byteoffset33
  %48 = load float, ptr %memoryref_data38, align 4
  %memoryref_byteoffset45 = shl i64 %value_phi14283, 2
  %memoryref_data50 = getelementptr inbounds i8, ptr %memoryref_data42, i64 %memoryref_byteoffset45
  %49 = load float, ptr %memoryref_data50, align 4
  %50 = fmul contract float %48, %48
  %51 = fadd reassoc contract float %value_phi15284, %50
  %52 = fmul contract float %48, %49
  %53 = fadd reassoc contract float %value_phi13282, %52
  %54 = fmul contract float %49, %49
  %55 = fadd reassoc contract float %value_phi12281, %54
  %exitcond.not = icmp eq i64 %47, %"m::SqrtLSModel.ls.r.size_ptr161.copyload"
  br i1 %exitcond.not, label %L299, label %L71

L178:                                             ; preds = %L51
  br i1 %8, label %L299, label %iter.check447

iter.check447:                                    ; preds = %L178
  %"m::SqrtLSModel.ls.X.size_ptr178" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls.X", i64 16
  %"m::SqrtLSModel.ls.X.size_ptr178.copyload" = load i64, ptr %"m::SqrtLSModel.ls.X.size_ptr178", align 8
  %56 = mul i64 %"m::SqrtLSModel.ls.X.size_ptr178.copyload", %5
  %memoryref_data185 = load ptr, ptr %"m::SqrtLSModel.ls.X", align 8
  %memoryref_data198 = load ptr, ptr %"m::SqrtLSModel.ls.r", align 8
  %min.iters.check445 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 4
  br i1 %min.iters.check445, label %L190, label %vector.main.loop.iter.check449

vector.main.loop.iter.check449:                   ; preds = %iter.check447
  %min.iters.check448 = icmp samesign ult i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 32
  br i1 %min.iters.check448, label %vec.epilog.ph484, label %vector.ph450

vector.ph450:                                     ; preds = %vector.main.loop.iter.check449
  %n.mod.vf451 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 28
  %n.vec452 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775776
  br label %vector.body453

vector.body453:                                   ; preds = %vector.body453, %vector.ph450
  %index454 = phi i64 [ 0, %vector.ph450 ], [ %index.next471, %vector.body453 ]
  %vec.phi455 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph450 ], [ %71, %vector.body453 ]
  %vec.phi456 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %72, %vector.body453 ]
  %vec.phi457 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %73, %vector.body453 ]
  %vec.phi458 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %74, %vector.body453 ]
  %vec.phi459 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph450 ], [ %79, %vector.body453 ]
  %vec.phi460 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %80, %vector.body453 ]
  %vec.phi461 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %81, %vector.body453 ]
  %vec.phi462 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph450 ], [ %82, %vector.body453 ]
  %.reass589 = add i64 %index454, %56
  %57 = shl i64 %.reass589, 2
  %58 = getelementptr inbounds i8, ptr %memoryref_data185, i64 %57
  %59 = getelementptr inbounds nuw i8, ptr %58, i64 32
  %60 = getelementptr inbounds nuw i8, ptr %58, i64 64
  %61 = getelementptr inbounds nuw i8, ptr %58, i64 96
  %wide.load463 = load <8 x float>, ptr %58, align 4
  %wide.load464 = load <8 x float>, ptr %59, align 4
  %wide.load465 = load <8 x float>, ptr %60, align 4
  %wide.load466 = load <8 x float>, ptr %61, align 4
  %62 = shl i64 %index454, 2
  %63 = getelementptr inbounds i8, ptr %memoryref_data198, i64 %62
  %64 = getelementptr inbounds nuw i8, ptr %63, i64 32
  %65 = getelementptr inbounds nuw i8, ptr %63, i64 64
  %66 = getelementptr inbounds nuw i8, ptr %63, i64 96
  %wide.load467 = load <8 x float>, ptr %63, align 4
  %wide.load468 = load <8 x float>, ptr %64, align 4
  %wide.load469 = load <8 x float>, ptr %65, align 4
  %wide.load470 = load <8 x float>, ptr %66, align 4
  %67 = fmul contract <8 x float> %wide.load463, %wide.load467
  %68 = fmul contract <8 x float> %wide.load464, %wide.load468
  %69 = fmul contract <8 x float> %wide.load465, %wide.load469
  %70 = fmul contract <8 x float> %wide.load466, %wide.load470
  %71 = fadd reassoc contract <8 x float> %vec.phi455, %67
  %72 = fadd reassoc contract <8 x float> %vec.phi456, %68
  %73 = fadd reassoc contract <8 x float> %vec.phi457, %69
  %74 = fadd reassoc contract <8 x float> %vec.phi458, %70
  %75 = fmul contract <8 x float> %wide.load467, %wide.load467
  %76 = fmul contract <8 x float> %wide.load468, %wide.load468
  %77 = fmul contract <8 x float> %wide.load469, %wide.load469
  %78 = fmul contract <8 x float> %wide.load470, %wide.load470
  %79 = fadd reassoc contract <8 x float> %vec.phi459, %75
  %80 = fadd reassoc contract <8 x float> %vec.phi460, %76
  %81 = fadd reassoc contract <8 x float> %vec.phi461, %77
  %82 = fadd reassoc contract <8 x float> %vec.phi462, %78
  %index.next471 = add nuw i64 %index454, 32
  %83 = icmp eq i64 %index.next471, %n.vec452
  br i1 %83, label %middle.block444, label %vector.body453

middle.block444:                                  ; preds = %vector.body453
  %bin.rdx472 = fadd reassoc contract <8 x float> %72, %71
  %bin.rdx473 = fadd reassoc contract <8 x float> %73, %bin.rdx472
  %bin.rdx474 = fadd reassoc contract <8 x float> %74, %bin.rdx473
  %84 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx474)
  %bin.rdx475 = fadd reassoc contract <8 x float> %80, %79
  %bin.rdx476 = fadd reassoc contract <8 x float> %81, %bin.rdx475
  %bin.rdx477 = fadd reassoc contract <8 x float> %82, %bin.rdx476
  %85 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx477)
  %cmp.n478 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec452
  br i1 %cmp.n478, label %L299, label %vec.epilog.iter.check485

vec.epilog.iter.check485:                         ; preds = %middle.block444
  %min.epilog.iters.check487 = icmp eq i64 %n.mod.vf451, 0
  br i1 %min.epilog.iters.check487, label %L190, label %vec.epilog.ph484

vec.epilog.ph484:                                 ; preds = %vec.epilog.iter.check485, %vector.main.loop.iter.check449
  %vec.epilog.resume.val479 = phi i64 [ %n.vec452, %vec.epilog.iter.check485 ], [ 0, %vector.main.loop.iter.check449 ]
  %bc.merge.rdx480 = phi float [ %84, %vec.epilog.iter.check485 ], [ 0.000000e+00, %vector.main.loop.iter.check449 ]
  %bc.merge.rdx481 = phi float [ %85, %vec.epilog.iter.check485 ], [ 0.000000e+00, %vector.main.loop.iter.check449 ]
  %n.vec489 = and i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", 9223372036854775804
  %86 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx480, i64 0
  %87 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx481, i64 0
  br label %vec.epilog.vector.body490

vec.epilog.vector.body490:                        ; preds = %vec.epilog.vector.body490, %vec.epilog.ph484
  %index491 = phi i64 [ %vec.epilog.resume.val479, %vec.epilog.ph484 ], [ %index.next496, %vec.epilog.vector.body490 ]
  %vec.phi492 = phi <4 x float> [ %86, %vec.epilog.ph484 ], [ %91, %vec.epilog.vector.body490 ]
  %vec.phi493 = phi <4 x float> [ %87, %vec.epilog.ph484 ], [ %93, %vec.epilog.vector.body490 ]
  %.reass591 = add i64 %index491, %56
  %88 = shl i64 %.reass591, 2
  %gep593 = getelementptr i8, ptr %memoryref_data185, i64 %88
  %wide.load494 = load <4 x float>, ptr %gep593, align 4
  %89 = shl i64 %index491, 2
  %gep595 = getelementptr i8, ptr %memoryref_data198, i64 %89
  %wide.load495 = load <4 x float>, ptr %gep595, align 4
  %90 = fmul contract <4 x float> %wide.load494, %wide.load495
  %91 = fadd reassoc contract <4 x float> %vec.phi492, %90
  %92 = fmul contract <4 x float> %wide.load495, %wide.load495
  %93 = fadd reassoc contract <4 x float> %vec.phi493, %92
  %index.next496 = add nuw i64 %index491, 4
  %94 = icmp eq i64 %index.next496, %n.vec489
  br i1 %94, label %vec.epilog.middle.block482, label %vec.epilog.vector.body490

vec.epilog.middle.block482:                       ; preds = %vec.epilog.vector.body490
  %95 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %91)
  %96 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %93)
  %cmp.n497 = icmp eq i64 %"m::SqrtLSModel.ls.r.size_ptr161.copyload", %n.vec489
  br i1 %cmp.n497, label %L299, label %L190

L190:                                             ; preds = %L190, %vec.epilog.middle.block482, %vec.epilog.iter.check485, %iter.check447
  %value_phi166287 = phi i64 [ %97, %L190 ], [ %n.vec489, %vec.epilog.middle.block482 ], [ 0, %iter.check447 ], [ %n.vec452, %vec.epilog.iter.check485 ]
  %value_phi165286 = phi float [ %101, %L190 ], [ %95, %vec.epilog.middle.block482 ], [ 0.000000e+00, %iter.check447 ], [ %84, %vec.epilog.iter.check485 ]
  %value_phi164285 = phi float [ %103, %L190 ], [ %96, %vec.epilog.middle.block482 ], [ 0.000000e+00, %iter.check447 ], [ %85, %vec.epilog.iter.check485 ]
  %97 = add nuw nsw i64 %value_phi166287, 1
  %memoryref_offset187 = add i64 %56, %value_phi166287
  %memoryref_byteoffset188 = shl i64 %memoryref_offset187, 2
  %memoryref_data193 = getelementptr inbounds i8, ptr %memoryref_data185, i64 %memoryref_byteoffset188
  %98 = load float, ptr %memoryref_data193, align 4
  %memoryref_byteoffset201 = shl i64 %value_phi166287, 2
  %memoryref_data206 = getelementptr inbounds i8, ptr %memoryref_data198, i64 %memoryref_byteoffset201
  %99 = load float, ptr %memoryref_data206, align 4
  %100 = fmul contract float %98, %99
  %101 = fadd reassoc contract float %value_phi165286, %100
  %102 = fmul contract float %99, %99
  %103 = fadd reassoc contract float %value_phi164285, %102
  %exitcond352.not = icmp eq i64 %97, %"m::SqrtLSModel.ls.r.size_ptr161.copyload"
  br i1 %exitcond352.not, label %L299, label %L190

L299:                                             ; preds = %L190, %vec.epilog.middle.block482, %middle.block444, %L178, %L71, %vec.epilog.middle.block531, %middle.block501, %L58
  %value_phi59 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %85, %middle.block444 ], [ %96, %vec.epilog.middle.block482 ], [ %31, %middle.block501 ], [ %46, %vec.epilog.middle.block531 ], [ %103, %L190 ], [ %55, %L71 ]
  %value_phi60 = phi float [ 0.000000e+00, %L58 ], [ 0.000000e+00, %L178 ], [ %84, %middle.block444 ], [ %95, %vec.epilog.middle.block482 ], [ %30, %middle.block501 ], [ %45, %vec.epilog.middle.block531 ], [ %101, %L190 ], [ %53, %L71 ]
  %value_phi61 = phi float [ 0.000000e+00, %L58 ], [ %6, %L178 ], [ %6, %middle.block444 ], [ %6, %vec.epilog.middle.block482 ], [ %29, %middle.block501 ], [ %44, %vec.epilog.middle.block531 ], [ %6, %L190 ], [ %51, %L71 ]
  %"xv::Array.size_ptr62.copyload" = load i64, ptr %"xv::Array.size_ptr", align 8
  %.not229 = icmp ult i64 %5, %"xv::Array.size_ptr62.copyload"
  br i1 %.not229, label %L311, label %L307

L307:                                             ; preds = %L299
  store i64 %value_phi9, ptr %"new::Tuple159", align 8
  call void @j_throw_boundserror_3144(ptr nonnull %"xv::Array", ptr nocapture nonnull readonly %"new::Tuple159") #16
  unreachable

L311:                                             ; preds = %L299
  %memoryref_data65 = load ptr, ptr %"xv::Array", align 8
  %memoryref_data73 = getelementptr inbounds i8, ptr %memoryref_data65, i64 %memoryref_byteoffset
  %104 = load float, ptr %memoryref_data73, align 4
  %"m::SqrtLSModel.ls74" = load atomic ptr, ptr %"m::SqrtLSModel" unordered, align 8
  %"m::SqrtLSModel.ls74.r_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74", i64 24
  %"m::SqrtLSModel.ls74.r" = load atomic ptr, ptr %"m::SqrtLSModel.ls74.r_ptr" unordered, align 8
  %"m::SqrtLSModel.ls74.r.size_ptr" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.r", i64 16
  %"m::SqrtLSModel.ls74.r.size_ptr.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.r.size_ptr", align 8
  %105 = fsub float %value_phi61, %value_phi61
  %106 = fcmp uno float %105, 0.000000e+00
  %107 = sitofp i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload" to float
  %108 = fmul float %107, 0x3980000000000000
  %109 = fcmp ugt float %108, %value_phi61
  %.not235 = or i1 %106, %109
  %110 = fsub float %value_phi59, %value_phi59
  %111 = fcmp uno float %110, 0.000000e+00
  %112 = fcmp ugt float %108, %value_phi59
  %.not238 = or i1 %111, %112
  %.not232 = or i1 %.not235, %.not238
  br i1 %.not232, label %L579, label %L337

L337:                                             ; preds = %L311
  %113 = fcmp uge float %value_phi61, 0.000000e+00
  br i1 %113, label %L343, label %L341

L341:                                             ; preds = %L337
  call void @j_throw_complex_domainerror_3148(ptr nonnull @"jl_sym#sqrt#3149.jit", float %value_phi61) #16
  unreachable

L343:                                             ; preds = %L337
  %"m::SqrtLSModel.gt_ptr.copyload239" = load float, ptr %"m::SqrtLSModel.gt_ptr", align 8
  %114 = call float @llvm.sqrt.f32(float %value_phi61)
  %115 = fcmp ugt float %114, %"m::SqrtLSModel.gt_ptr.copyload239"
  br i1 %115, label %L348, label %L581

L348:                                             ; preds = %L343
  %116 = fdiv float %value_phi60, %value_phi61
  %117 = fadd float %116, %104
  %118 = fmul float %value_phi60, %116
  %119 = fsub float %value_phi59, %118
  %120 = fmul float %value_phi59, 6.250000e-02
  %121 = fcmp uge float %119, %120
  br i1 %121, label %L483, label %L355

L355:                                             ; preds = %L348
  %122 = icmp slt i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 1
  br i1 %122, label %L471, label %iter.check

iter.check:                                       ; preds = %L355
  %"m::SqrtLSModel.ls74.X" = load atomic ptr, ptr %"m::SqrtLSModel.ls74" unordered, align 8
  %memoryref_data97 = load ptr, ptr %"m::SqrtLSModel.ls74.r", align 8
  %"m::SqrtLSModel.ls74.X.size_ptr112" = getelementptr inbounds nuw i8, ptr %"m::SqrtLSModel.ls74.X", i64 16
  %"m::SqrtLSModel.ls74.X.size_ptr112.copyload" = load i64, ptr %"m::SqrtLSModel.ls74.X.size_ptr112", align 8
  %123 = mul i64 %"m::SqrtLSModel.ls74.X.size_ptr112.copyload", %5
  %memoryref_data118 = load ptr, ptr %"m::SqrtLSModel.ls74.X", align 8
  %min.iters.check = icmp samesign ult i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 4
  br i1 %min.iters.check, label %L368, label %vector.main.loop.iter.check

vector.main.loop.iter.check:                      ; preds = %iter.check
  %min.iters.check420 = icmp samesign ult i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 32
  br i1 %min.iters.check420, label %vec.epilog.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.main.loop.iter.check
  %n.mod.vf = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 28
  %n.vec = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %116, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %146, %vector.body ]
  %vec.phi421 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %147, %vector.body ]
  %vec.phi422 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %148, %vector.body ]
  %vec.phi423 = phi <8 x float> [ splat (float -0.000000e+00), %vector.ph ], [ %149, %vector.body ]
  %124 = shl i64 %index, 2
  %125 = getelementptr inbounds i8, ptr %memoryref_data97, i64 %124
  %126 = getelementptr inbounds nuw i8, ptr %125, i64 32
  %127 = getelementptr inbounds nuw i8, ptr %125, i64 64
  %128 = getelementptr inbounds nuw i8, ptr %125, i64 96
  %wide.load = load <8 x float>, ptr %125, align 4
  %wide.load424 = load <8 x float>, ptr %126, align 4
  %wide.load425 = load <8 x float>, ptr %127, align 4
  %wide.load426 = load <8 x float>, ptr %128, align 4
  %.reass597 = add i64 %index, %123
  %129 = shl i64 %.reass597, 2
  %130 = getelementptr inbounds i8, ptr %memoryref_data118, i64 %129
  %131 = getelementptr inbounds nuw i8, ptr %130, i64 32
  %132 = getelementptr inbounds nuw i8, ptr %130, i64 64
  %133 = getelementptr inbounds nuw i8, ptr %130, i64 96
  %wide.load427 = load <8 x float>, ptr %130, align 4
  %wide.load428 = load <8 x float>, ptr %131, align 4
  %wide.load429 = load <8 x float>, ptr %132, align 4
  %wide.load430 = load <8 x float>, ptr %133, align 4
  %134 = fmul <8 x float> %broadcast.splat, %wide.load427
  %135 = fmul <8 x float> %broadcast.splat, %wide.load428
  %136 = fmul <8 x float> %broadcast.splat, %wide.load429
  %137 = fmul <8 x float> %broadcast.splat, %wide.load430
  %138 = fsub <8 x float> %wide.load, %134
  %139 = fsub <8 x float> %wide.load424, %135
  %140 = fsub <8 x float> %wide.load425, %136
  %141 = fsub <8 x float> %wide.load426, %137
  %142 = fmul contract <8 x float> %138, %138
  %143 = fmul contract <8 x float> %139, %139
  %144 = fmul contract <8 x float> %140, %140
  %145 = fmul contract <8 x float> %141, %141
  %146 = fadd reassoc contract <8 x float> %vec.phi, %142
  %147 = fadd reassoc contract <8 x float> %vec.phi421, %143
  %148 = fadd reassoc contract <8 x float> %vec.phi422, %144
  %149 = fadd reassoc contract <8 x float> %vec.phi423, %145
  %index.next = add nuw i64 %index, 32
  %150 = icmp eq i64 %index.next, %n.vec
  br i1 %150, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %147, %146
  %bin.rdx431 = fadd reassoc contract <8 x float> %148, %bin.rdx
  %bin.rdx432 = fadd reassoc contract <8 x float> %149, %bin.rdx431
  %151 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx432)
  %cmp.n = icmp eq i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", %n.vec
  br i1 %cmp.n, label %L471, label %vec.epilog.iter.check

vec.epilog.iter.check:                            ; preds = %middle.block
  %min.epilog.iters.check = icmp eq i64 %n.mod.vf, 0
  br i1 %min.epilog.iters.check, label %L368, label %vec.epilog.ph

vec.epilog.ph:                                    ; preds = %vec.epilog.iter.check, %vector.main.loop.iter.check
  %vec.epilog.resume.val = phi i64 [ %n.vec, %vec.epilog.iter.check ], [ 0, %vector.main.loop.iter.check ]
  %bc.merge.rdx = phi float [ %151, %vec.epilog.iter.check ], [ 0.000000e+00, %vector.main.loop.iter.check ]
  %n.vec434 = and i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", 9223372036854775804
  %152 = insertelement <4 x float> <float poison, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, float %bc.merge.rdx, i64 0
  %broadcast.splatinsert439 = insertelement <4 x float> poison, float %116, i64 0
  %broadcast.splat440 = shufflevector <4 x float> %broadcast.splatinsert439, <4 x float> poison, <4 x i32> zeroinitializer
  br label %vec.epilog.vector.body

vec.epilog.vector.body:                           ; preds = %vec.epilog.vector.body, %vec.epilog.ph
  %index435 = phi i64 [ %vec.epilog.resume.val, %vec.epilog.ph ], [ %index.next441, %vec.epilog.vector.body ]
  %vec.phi436 = phi <4 x float> [ %152, %vec.epilog.ph ], [ %158, %vec.epilog.vector.body ]
  %153 = shl i64 %index435, 2
  %gep599 = getelementptr i8, ptr %memoryref_data97, i64 %153
  %wide.load437 = load <4 x float>, ptr %gep599, align 4
  %.reass601 = add i64 %index435, %123
  %154 = shl i64 %.reass601, 2
  %gep603 = getelementptr i8, ptr %memoryref_data118, i64 %154
  %wide.load438 = load <4 x float>, ptr %gep603, align 4
  %155 = fmul <4 x float> %broadcast.splat440, %wide.load438
  %156 = fsub <4 x float> %wide.load437, %155
  %157 = fmul contract <4 x float> %156, %156
  %158 = fadd reassoc contract <4 x float> %vec.phi436, %157
  %index.next441 = add nuw i64 %index435, 4
  %159 = icmp eq i64 %index.next441, %n.vec434
  br i1 %159, label %vec.epilog.middle.block, label %vec.epilog.vector.body

vec.epilog.middle.block:                          ; preds = %vec.epilog.vector.body
  %160 = call reassoc contract float @llvm.vector.reduce.fadd.v4f32(float -0.000000e+00, <4 x float> %158)
  %cmp.n442 = icmp eq i64 %"m::SqrtLSModel.ls74.r.size_ptr.copyload", %n.vec434
  br i1 %cmp.n442, label %L471, label %L368

L368:                                             ; preds = %L368, %vec.epilog.middle.block, %vec.epilog.iter.check, %iter.check
  %value_phi90289 = phi i64 [ %161, %L368 ], [ %n.vec434, %vec.epilog.middle.block ], [ 0, %iter.check ], [ %n.vec, %vec.epilog.iter.check ]
  %value_phi89288 = phi float [ %167, %L368 ], [ %160, %vec.epilog.middle.block ], [ 0.000000e+00, %iter.check ], [ %151, %vec.epilog.iter.check ]
  %161 = add nuw nsw i64 %value_phi90289, 1
  %memoryref_byteoffset100 = shl i64 %value_phi90289, 2
  %memoryref_data105 = getelementptr inbounds i8, ptr %memoryref_data97, i64 %memoryref_byteoffset100
  %162 = load float, ptr %memoryref_data105, align 4
  %memoryref_offset120 = add i64 %123, %value_phi90289
  %memoryref_byteoffset121 = shl i64 %memoryref_offset120, 2
  %memoryref_data126 = getelementptr inbounds i8, ptr %memoryref_data118, i64 %memoryref_byteoffset121
  %163 = load float, ptr %memoryref_data126, align 4
  %164 = fmul float %116, %163
  %165 = fsub float %162, %164
  %166 = fmul contract float %165, %165
  %167 = fadd reassoc contract float %value_phi89288, %166
  %exitcond353.not = icmp eq i64 %161, %"m::SqrtLSModel.ls74.r.size_ptr.copyload"
  br i1 %exitcond353.not, label %L471, label %L368

L471:                                             ; preds = %L368, %vec.epilog.middle.block, %middle.block, %L355
  %value_phi133 = phi float [ 0.000000e+00, %L355 ], [ %151, %middle.block ], [ %160, %vec.epilog.middle.block ], [ %167, %L368 ]
  %168 = fsub float %value_phi133, %value_phi133
  %169 = fcmp uno float %168, 0.000000e+00
  %170 = fcmp ugt float %108, %value_phi133
  %.not243 = or i1 %170, %169
  br i1 %.not243, label %L481, label %L483

L481:                                             ; preds = %L471
  %gc_slot_addr_0658 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0658, align 8
  %171 = call float @j__sqrt_offrange_step_3152(ptr nonnull %"m::SqrtLSModel", float %104, i64 signext %value_phi9)
  br label %L581

L483:                                             ; preds = %L471, %L348
  %value_phi135 = phi float [ %119, %L348 ], [ %value_phi133, %L471 ]
  %172 = fcmp uge float %value_phi135, 0.000000e+00
  br i1 %172, label %L488, label %L486

L486:                                             ; preds = %L483
  call void @j_throw_complex_domainerror_3148(ptr nonnull @"jl_sym#sqrt#3149.jit", float %value_phi135) #16
  unreachable

L488:                                             ; preds = %L483
  %173 = call float @llvm.sqrt.f32(float %value_phi135)
  %174 = fsub float %114, %"m::SqrtLSModel.gt_ptr.copyload239"
  %175 = fcmp uge float %174, 0.000000e+00
  br i1 %175, label %L495, label %L493

L493:                                             ; preds = %L488
  call void @j_throw_complex_domainerror_3148(ptr nonnull @"jl_sym#sqrt#3149.jit", float %174) #16
  unreachable

L495:                                             ; preds = %L488
  %176 = fadd float %114, %"m::SqrtLSModel.gt_ptr.copyload239"
  %177 = fcmp uge float %176, 0.000000e+00
  br i1 %177, label %L502, label %L500

L500:                                             ; preds = %L495
  call void @j_throw_complex_domainerror_3148(ptr nonnull @"jl_sym#sqrt#3149.jit", float %176) #16
  unreachable

L502:                                             ; preds = %L495
  %178 = call float @llvm.sqrt.f32(float %174)
  %179 = call float @llvm.sqrt.f32(float %176)
  %180 = fmul float %178, %179
  %181 = fmul float %114, %180
  %182 = fdiv float %173, %181
  %183 = fmul float %"m::SqrtLSModel.gt_ptr.copyload239", %182
  %184 = fcmp ult float %181, 0x3810000000000000
  %185 = fcmp ult float %182, 0x3810000000000000
  %186 = fcmp ugt float %182, 0x47EFFFFFE0000000
  %narrow.not251 = or i1 %185, %186
  %.not248 = or i1 %184, %narrow.not251
  %187 = fcmp ult float %183, 0x3810000000000000
  %188 = fcmp ugt float %183, 0x47EFFFFFE0000000
  %narrow244.not254 = or i1 %187, %188
  %.not246 = or i1 %.not248, %narrow244.not254
  br i1 %.not246, label %L576, label %L535

L535:                                             ; preds = %L502
  %189 = fneg float %183
  %.inv = fcmp ogt float %117, %189
  %190 = select i1 %.inv, float %117, float %189
  %.inv255 = fcmp olt float %190, %183
  %191 = select i1 %.inv255, float %190, float %183
  %192 = fsub float %117, %191
  %193 = fadd float %192, 0.000000e+00
  br label %L581

L576:                                             ; preds = %L502
  %194 = fpext float %173 to double
  %gc_slot_addr_0659 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0659, align 8
  %195 = call float @j__sqrt_band_step_3151(float %117, float %114, float %"m::SqrtLSModel.gt_ptr.copyload239", double %194, i64 signext 0)
  br label %L581

L579:                                             ; preds = %L311
  %gc_slot_addr_0660 = getelementptr inbounds nuw i8, ptr %gcframe1, i64 16
  store ptr %"m::SqrtLSModel.ls", ptr %gc_slot_addr_0660, align 8
  %196 = call float @j__sqrt_offrange_step_3152(ptr nonnull %"m::SqrtLSModel", float %104, i64 signext %value_phi9)
  br label %L581

L581:                                             ; preds = %L579, %L576, %L535, %L481, %L343
  %value_phi77 = phi float [ %171, %L481 ], [ %195, %L576 ], [ %196, %L579 ], [ 0.000000e+00, %L343 ], [ %193, %L535 ]
  %197 = fadd float %value_phi8, %value_phi77
  %.not256 = icmp eq i64 %value_phi9, %"xv::Array.size_ptr.copyload"
  %198 = add nuw i64 %value_phi9, 1
  br i1 %.not256, label %L594, label %L31

L594:                                             ; preds = %L581, %L17
  %value_phi82 = phi float [ %value_phi4, %L17 ], [ %197, %L581 ]
  %.not257 = icmp eq i64 %value_phi3, %".reps::Int64"
  br i1 %.not257, label %L605, label %L17thread-pre-split

L605:                                             ; preds = %L594, %L17.preheader, %top
  %value_phi85 = phi float [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi82, %L594 ]
  %frame.prev668 = load ptr, ptr %frame.prev, align 8
  store ptr %frame.prev668, ptr %tls_pgcstack, align 8
  ret float %value_phi85
}
