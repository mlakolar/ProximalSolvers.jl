define float @"julia__sweep!_1553"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(72) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(48) %3, i8 zeroext %4, [1 x i64]* nocapture noundef nonnull readonly align 8 dereferenceable(8) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1798 = alloca [5 x {}*], align 16
  %gcframe1798.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1798 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct73 = alloca [1 x i64], align 8
  %newstruct108 = alloca [1 x i64], align 8
  %newstruct349 = alloca [1 x i64], align 8
  %newstruct382 = alloca [1 x i64], align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #12
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [5 x {}*]* %gcframe1798 to i64*
  store i64 12, i64* %9, align 16
  %10 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe1798.sub, {}*** %13, align 8
  %14 = getelementptr inbounds [1 x i64], [1 x i64]* %5, i64 0, i64 0
  %15 = bitcast {}* %3 to i8*
  %16 = load i8, i8* %15, align 8
  %17 = and i8 %16, 1
  %.not = icmp eq i8 %17, 0
  br i1 %.not, label %L530, label %L4

L4:                                               ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %15, i64 8
  %18 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %18 unordered, align 8
  %unbox = load i64, i64* %14, align 8
  %19 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield, {}** %19, align 16
  %20 = call nonnull {}* @"j__shuffle!_1555"({}* nonnull %getfield, i64 signext %unbox)
  %unbox540 = load i64, i64* %14, align 8
  %.inv = icmp sgt i64 %unbox, 0
  %value_phi = select i1 %.inv, i64 %unbox540, i64 0
  %21 = icmp slt i64 %value_phi, 1
  br i1 %21, label %L1051, label %L22.preheader

L22.preheader:                                    ; preds = %L4
  %22 = bitcast {}* %20 to i64**
  %23 = bitcast {}* %1 to {}**
  %24 = bitcast {}* %0 to i8*
  %getfield_addr71 = getelementptr inbounds i8, i8* %24, i64 16
  %25 = bitcast i8* %getfield_addr71 to {}**
  %26 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct73, i64 0, i64 0
  %27 = bitcast {}* %0 to {}**
  %28 = bitcast {}* %1 to i8*
  %29 = getelementptr inbounds i8, i8* %28, i64 8
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %29 to float*
  %30 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct108, i64 0, i64 0
  %31 = getelementptr inbounds i8, i8* %24, i64 24
  %32 = bitcast i8* %31 to i64*
  %getfield_addr152 = getelementptr inbounds i8, i8* %24, i64 8
  %33 = bitcast i8* %getfield_addr152 to {}**
  %34 = and i8 %4, 1
  %.not614 = icmp eq i8 %34, 0
  br label %L22

L22:                                              ; preds = %L513, %L22.preheader
  %arrayref937 = phi i64 [ %arrayref936, %L513 ], [ undef, %L22.preheader ]
  %value_phi5 = phi i64 [ %283, %L513 ], [ 1, %L22.preheader ]
  %value_phi7 = phi float [ %282, %L513 ], [ 0.000000e+00, %L22.preheader ]
  %35 = add nsw i64 %value_phi5, -1
  %arrayptr600 = load i64*, i64** %22, align 8
  %36 = getelementptr inbounds i64, i64* %arrayptr600, i64 %35
  %arrayref = load i64, i64* %36, align 8
  %getfield10 = load atomic {}*, {}** %23 unordered, align 8
  %37 = bitcast {}* %getfield10 to {}**
  %getfield12 = load atomic {}*, {}** %37 unordered, align 8
  %38 = bitcast {}* %getfield10 to i8*
  %getfield_addr13 = getelementptr inbounds i8, i8* %38, i64 24
  %39 = bitcast i8* %getfield_addr13 to {}**
  %getfield14 = load atomic {}*, {}** %39 unordered, align 8
  %getfield_addr15 = getelementptr inbounds i8, i8* %38, i64 32
  %40 = bitcast i8* %getfield_addr15 to {}**
  %getfield16 = load atomic {}*, {}** %40 unordered, align 8
  %41 = add i64 %arrayref, -1
  %42 = bitcast {}* %getfield16 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %42, i64 0, i32 1
  %arraylen = load i64, i64* %arraylen_ptr, align 8
  %inbounds = icmp ult i64 %41, %arraylen
  br i1 %inbounds, label %idxend, label %oob

L43:                                              ; preds = %idxend
  br i1 %.not639, label %L127, label %L57.lr.ph

L57.lr.ph:                                        ; preds = %L43
  %43 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr = getelementptr inbounds {}*, {}** %43, i64 3
  %44 = bitcast {}** %arraysize_ptr to i64*
  %arraysize = load i64, i64* %44, align 8
  %45 = mul i64 %arraysize, %41
  %46 = bitcast {}* %getfield12 to float**
  %arrayptr27604 = load float*, float** %46, align 8
  %47 = bitcast {}* %getfield14 to float**
  %arrayptr30605 = load float*, float** %47, align 8
  %min.iters.check1508 = icmp ult i64 %arraylen241, 8
  br i1 %min.iters.check1508, label %scalar.ph1507, label %vector.ph1509

vector.ph1509:                                    ; preds = %L57.lr.ph
  %n.vec1511 = and i64 %arraylen241, 9223372036854775800
  br label %vector.body1514

vector.body1514:                                  ; preds = %vector.body1514, %vector.ph1509
  %index1515 = phi i64 [ 0, %vector.ph1509 ], [ %index.next1521, %vector.body1514 ]
  %vec.phi1516 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1509 ], [ %54, %vector.body1514 ]
  %vec.phi1517 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1509 ], [ %56, %vector.body1514 ]
  %vec.phi1518 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1509 ], [ %58, %vector.body1514 ]
  %48 = add i64 %45, %index1515
  %49 = getelementptr inbounds float, float* %arrayptr27604, i64 %48
  %50 = bitcast float* %49 to <8 x float>*
  %wide.load1519 = load <8 x float>, <8 x float>* %50, align 4
  %51 = getelementptr inbounds float, float* %arrayptr30605, i64 %index1515
  %52 = bitcast float* %51 to <8 x float>*
  %wide.load1520 = load <8 x float>, <8 x float>* %52, align 4
  %53 = fmul contract <8 x float> %wide.load1519, %wide.load1519
  %54 = fadd reassoc contract <8 x float> %vec.phi1516, %53
  %55 = fmul contract <8 x float> %wide.load1519, %wide.load1520
  %56 = fadd reassoc contract <8 x float> %vec.phi1517, %55
  %57 = fmul contract <8 x float> %wide.load1520, %wide.load1520
  %58 = fadd reassoc contract <8 x float> %vec.phi1518, %57
  %index.next1521 = add nuw i64 %index1515, 8
  %59 = icmp eq i64 %index.next1521, %n.vec1511
  br i1 %59, label %middle.block1506, label %vector.body1514

middle.block1506:                                 ; preds = %vector.body1514
  %60 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %58)
  %61 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %56)
  %62 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %54)
  %cmp.n1513 = icmp eq i64 %arraylen241, %n.vec1511
  br i1 %cmp.n1513, label %L127, label %scalar.ph1507

scalar.ph1507:                                    ; preds = %middle.block1506, %L57.lr.ph
  %bc.resume.val1512 = phi i64 [ %n.vec1511, %middle.block1506 ], [ 0, %L57.lr.ph ]
  %bc.merge.rdx1522 = phi float [ %62, %middle.block1506 ], [ 0.000000e+00, %L57.lr.ph ]
  %bc.merge.rdx1523 = phi float [ %61, %middle.block1506 ], [ 0.000000e+00, %L57.lr.ph ]
  %bc.merge.rdx1524 = phi float [ %60, %middle.block1506 ], [ 0.000000e+00, %L57.lr.ph ]
  br label %L57

L57:                                              ; preds = %L57, %scalar.ph1507
  %value_phi25859 = phi float [ %bc.merge.rdx1522, %scalar.ph1507 ], [ %67, %L57 ]
  %value_phi24858 = phi i64 [ %bc.resume.val1512, %scalar.ph1507 ], [ %72, %L57 ]
  %value_phi23857 = phi float [ %bc.merge.rdx1523, %scalar.ph1507 ], [ %69, %L57 ]
  %value_phi22856 = phi float [ %bc.merge.rdx1524, %scalar.ph1507 ], [ %71, %L57 ]
  %63 = add i64 %45, %value_phi24858
  %64 = getelementptr inbounds float, float* %arrayptr27604, i64 %63
  %arrayref28 = load float, float* %64, align 4
  %65 = getelementptr inbounds float, float* %arrayptr30605, i64 %value_phi24858
  %arrayref31 = load float, float* %65, align 4
  %66 = fmul contract float %arrayref28, %arrayref28
  %67 = fadd reassoc contract float %value_phi25859, %66
  %68 = fmul contract float %arrayref28, %arrayref31
  %69 = fadd reassoc contract float %value_phi23857, %68
  %70 = fmul contract float %arrayref31, %arrayref31
  %71 = fadd reassoc contract float %value_phi22856, %70
  %72 = add nuw nsw i64 %value_phi24858, 1
  %exitcond.not = icmp eq i64 %72, %arraylen241
  br i1 %exitcond.not, label %L127, label %L57

L86:                                              ; preds = %idxend
  br i1 %.not639, label %L127, label %L99.lr.ph

L99.lr.ph:                                        ; preds = %L86
  %73 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr247 = getelementptr inbounds {}*, {}** %73, i64 3
  %74 = bitcast {}** %arraysize_ptr247 to i64*
  %arraysize248 = load i64, i64* %74, align 8
  %75 = mul i64 %arraysize248, %41
  %76 = bitcast {}* %getfield12 to float**
  %arrayptr251641 = load float*, float** %76, align 8
  %77 = bitcast {}* %getfield14 to float**
  %arrayptr254642 = load float*, float** %77, align 8
  %min.iters.check1485 = icmp ult i64 %arraylen241, 16
  br i1 %min.iters.check1485, label %scalar.ph1484, label %vector.ph1486

vector.ph1486:                                    ; preds = %L99.lr.ph
  %n.vec1488 = and i64 %arraylen241, 9223372036854775792
  br label %vector.body1491

vector.body1491:                                  ; preds = %vector.body1491, %vector.ph1486
  %index1492 = phi i64 [ 0, %vector.ph1486 ], [ %index.next1501, %vector.body1491 ]
  %vec.phi1493 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %89, %vector.body1491 ]
  %vec.phi1494 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %90, %vector.body1491 ]
  %vec.phi1495 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %93, %vector.body1491 ]
  %vec.phi1496 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %94, %vector.body1491 ]
  %78 = add i64 %75, %index1492
  %79 = getelementptr inbounds float, float* %arrayptr251641, i64 %78
  %80 = bitcast float* %79 to <8 x float>*
  %wide.load1497 = load <8 x float>, <8 x float>* %80, align 4
  %81 = getelementptr inbounds float, float* %79, i64 8
  %82 = bitcast float* %81 to <8 x float>*
  %wide.load1498 = load <8 x float>, <8 x float>* %82, align 4
  %83 = getelementptr inbounds float, float* %arrayptr254642, i64 %index1492
  %84 = bitcast float* %83 to <8 x float>*
  %wide.load1499 = load <8 x float>, <8 x float>* %84, align 4
  %85 = getelementptr inbounds float, float* %83, i64 8
  %86 = bitcast float* %85 to <8 x float>*
  %wide.load1500 = load <8 x float>, <8 x float>* %86, align 4
  %87 = fmul contract <8 x float> %wide.load1497, %wide.load1499
  %88 = fmul contract <8 x float> %wide.load1498, %wide.load1500
  %89 = fadd reassoc contract <8 x float> %vec.phi1493, %87
  %90 = fadd reassoc contract <8 x float> %vec.phi1494, %88
  %91 = fmul contract <8 x float> %wide.load1499, %wide.load1499
  %92 = fmul contract <8 x float> %wide.load1500, %wide.load1500
  %93 = fadd reassoc contract <8 x float> %vec.phi1495, %91
  %94 = fadd reassoc contract <8 x float> %vec.phi1496, %92
  %index.next1501 = add nuw i64 %index1492, 16
  %95 = icmp eq i64 %index.next1501, %n.vec1488
  br i1 %95, label %middle.block1483, label %vector.body1491

middle.block1483:                                 ; preds = %vector.body1491
  %bin.rdx1504 = fadd reassoc contract <8 x float> %94, %93
  %96 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1504)
  %bin.rdx1502 = fadd reassoc contract <8 x float> %90, %89
  %97 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1502)
  %cmp.n1490 = icmp eq i64 %arraylen241, %n.vec1488
  br i1 %cmp.n1490, label %L127, label %scalar.ph1484

scalar.ph1484:                                    ; preds = %middle.block1483, %L99.lr.ph
  %bc.resume.val1489 = phi i64 [ %n.vec1488, %middle.block1483 ], [ 0, %L99.lr.ph ]
  %bc.merge.rdx1503 = phi float [ %97, %middle.block1483 ], [ 0.000000e+00, %L99.lr.ph ]
  %bc.merge.rdx1505 = phi float [ %96, %middle.block1483 ], [ 0.000000e+00, %L99.lr.ph ]
  br label %L99

L99:                                              ; preds = %L99, %scalar.ph1484
  %value_phi246865 = phi i64 [ %bc.resume.val1489, %scalar.ph1484 ], [ %105, %L99 ]
  %value_phi245864 = phi float [ %bc.merge.rdx1503, %scalar.ph1484 ], [ %102, %L99 ]
  %value_phi244863 = phi float [ %bc.merge.rdx1505, %scalar.ph1484 ], [ %104, %L99 ]
  %98 = add i64 %75, %value_phi246865
  %99 = getelementptr inbounds float, float* %arrayptr251641, i64 %98
  %arrayref252 = load float, float* %99, align 4
  %100 = getelementptr inbounds float, float* %arrayptr254642, i64 %value_phi246865
  %arrayref255 = load float, float* %100, align 4
  %101 = fmul contract float %arrayref252, %arrayref255
  %102 = fadd reassoc contract float %value_phi245864, %101
  %103 = fmul contract float %arrayref255, %arrayref255
  %104 = fadd reassoc contract float %value_phi244863, %103
  %105 = add nuw nsw i64 %value_phi246865, 1
  %exitcond1039.not = icmp eq i64 %105, %arraylen241
  br i1 %exitcond1039.not, label %L127, label %L99

L127:                                             ; preds = %L99, %middle.block1483, %L86, %L57, %middle.block1506, %L43
  %value_phi38 = phi float [ 0.000000e+00, %L43 ], [ 0.000000e+00, %L86 ], [ %96, %middle.block1483 ], [ %60, %middle.block1506 ], [ %104, %L99 ], [ %71, %L57 ]
  %value_phi39 = phi float [ 0.000000e+00, %L43 ], [ 0.000000e+00, %L86 ], [ %97, %middle.block1483 ], [ %61, %middle.block1506 ], [ %102, %L99 ], [ %69, %L57 ]
  %value_phi40 = phi float [ 0.000000e+00, %L43 ], [ %arrayref19, %L86 ], [ %arrayref19, %middle.block1483 ], [ %62, %middle.block1506 ], [ %arrayref19, %L99 ], [ %67, %L57 ]
  %106 = fsub float %value_phi38, %value_phi38
  %107 = fcmp uno float %106, 0.000000e+00
  br i1 %107, label %L132, label %L134

L132:                                             ; preds = %L127
  %108 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %108, align 8
  %109 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %109, align 16
  store {}* %getfield14, {}** %19, align 16
  call void @j__check_residual_1565({}* nonnull %getfield14, i64 signext %arrayref)
  br label %L134

L134:                                             ; preds = %L132, %L127
  %110 = fcmp une float %value_phi40, 0.000000e+00
  br i1 %110, label %L175, label %L136

L136:                                             ; preds = %L134
  %getfield42 = load atomic {}*, {}** %37 unordered, align 8
  %111 = bitcast {}* %getfield42 to {}**
  %arraysize_ptr43 = getelementptr inbounds {}*, {}** %111, i64 3
  %112 = bitcast {}** %arraysize_ptr43 to i64*
  %arraysize44 = load i64, i64* %112, align 8
  %.not606.not = icmp eq i64 %arraysize44, 0
  br i1 %.not606.not, label %L175, label %L149.preheader

L149.preheader:                                   ; preds = %L136
  %arraysize_ptr57 = getelementptr inbounds {}*, {}** %111, i64 4
  %113 = bitcast {}** %arraysize_ptr57 to i64*
  %arraysize58 = load i64, i64* %113, align 8
  %inbounds59 = icmp ult i64 %41, %arraysize58
  %114 = mul i64 %arraysize44, %41
  %115 = bitcast {}* %getfield42 to float**
  %arrayptr64608 = load float*, float** %115, align 8
  %inbounds59.fr = freeze i1 %inbounds59
  br i1 %inbounds59.fr, label %ib.us, label %oob60

ib.us:                                            ; preds = %L155.us, %L149.preheader
  %value_phi49.us = phi i64 [ %120, %L155.us ], [ 1, %L149.preheader ]
  %116 = add nsw i64 %value_phi49.us, -1
  %117 = add i64 %114, %116
  %118 = getelementptr inbounds float, float* %arrayptr64608, i64 %117
  %arrayref65.us = load float, float* %118, align 4
  %119 = fcmp une float %arrayref65.us, 0.000000e+00
  br i1 %119, label %L171.split.us, label %L155.us

L155.us:                                          ; preds = %ib.us
  %120 = add nuw nsw i64 %value_phi49.us, 1
  %121 = icmp ult i64 %value_phi49.us, %arraysize44
  br i1 %121, label %ib.us, label %L175

L171.split.us:                                    ; preds = %ib.us
  store {}* inttoptr (i64 135794568225424 to {}*), {}** %6, align 8
  %122 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %122)
  unreachable

L175:                                             ; preds = %L155.us, %L136, %L134
  %123 = fsub float %value_phi40, %value_phi40
  %124 = fcmp uno float %123, 0.000000e+00
  br i1 %124, label %L491, label %L180

L180:                                             ; preds = %L175
  %getfield72 = load atomic {}*, {}** %25 unordered, align 8
  %125 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr74 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %125, i64 0, i32 1
  %arraylen75 = load i64, i64* %arraylen_ptr74, align 8
  %.not610 = icmp ult i64 %41, %arraylen75
  br i1 %.not610, label %L194, label %L191

L191:                                             ; preds = %L180
  store i64 %arrayref, i64* %26, align 8
  store {}* %getfield72, {}** %19, align 16
  call void @j_throw_boundserror_1559({}* nonnull %getfield72, [1 x i64]* nocapture readonly %newstruct73) #2
  unreachable

L194:                                             ; preds = %L180
  %126 = bitcast {}* %getfield72 to i64**
  %arrayptr80611 = load i64*, i64** %126, align 8
  %127 = getelementptr inbounds i64, i64* %arrayptr80611, i64 %41
  %arrayref81 = load i64, i64* %127, align 8
  %.not612 = icmp eq i64 %arrayref81, 0
  br i1 %.not612, label %L204, label %L199

L199:                                             ; preds = %L194
  %128 = bitcast {}* %0 to float***
  %getfield2321799 = load atomic float**, float*** %128 unordered, align 8
  %129 = add i64 %arrayref81, -1
  %arrayptr234638 = load float*, float** %getfield2321799, align 8
  %130 = getelementptr inbounds float, float* %arrayptr234638, i64 %129
  %arrayref235 = load float, float* %130, align 4
  br label %L204

L204:                                             ; preds = %L199, %L194
  %value_phi82 = phi float [ %arrayref235, %L199 ], [ 0.000000e+00, %L194 ]
  br i1 %110, label %L208, label %L206

L206:                                             ; preds = %L204
  %131 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %131, align 8
  %132 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %132, align 16
  %133 = call float @j__coordinate_minimizer_1557({ double }* nocapture nonnull readonly %2, float %value_phi82, i64 signext %arrayref)
  br label %L409

L208:                                             ; preds = %L204
  %getfield174 = load atomic {}*, {}** %23 unordered, align 8
  %134 = bitcast {}* %getfield174 to i8*
  %getfield_addr175 = getelementptr inbounds i8, i8* %134, i64 24
  %135 = bitcast i8* %getfield_addr175 to {}**
  %getfield176 = load atomic {}*, {}** %135 unordered, align 8
  %136 = bitcast {}* %getfield176 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr177 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %136, i64 0, i32 1
  %arraylen178 = load i64, i64* %arraylen_ptr177, align 8
  %137 = sitofp i64 %arraylen178 to float
  %138 = fmul float %137, 0x3980000000000000
  %139 = fcmp ole float %138, %value_phi40
  %140 = fcmp ord float %106, 0.000000e+00
  %141 = fcmp ole float %138, %value_phi38
  %142 = and i1 %140, %141
  %143 = and i1 %139, %142
  br i1 %143, label %L227, label %L406

L227:                                             ; preds = %L208
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %144 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %144, label %L233, label %L231

L231:                                             ; preds = %L227
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %value_phi40) #2
  unreachable

L233:                                             ; preds = %L227
  %145 = call float @llvm.sqrt.f32(float %value_phi40)
  %146 = fcmp ugt float %145, %aggregate_load_box.sroa.0.0.copyload
  br i1 %146, label %L238, label %L409

L238:                                             ; preds = %L233
  %147 = fdiv float %value_phi39, %value_phi40
  %148 = fadd float %147, %value_phi82
  %149 = fmul float %value_phi39, %147
  %150 = fsub float %value_phi38, %149
  %151 = fmul float %value_phi38, 6.250000e-02
  %152 = fcmp uge float %150, %151
  br i1 %152, label %L293, label %L245

L245:                                             ; preds = %L238
  %.not629 = icmp eq i64 %arraylen178, 0
  br i1 %.not629, label %L282, label %L259.lr.ph

L259.lr.ph:                                       ; preds = %L245
  %153 = bitcast {}* %getfield174 to {}**
  %getfield183 = load atomic {}*, {}** %153 unordered, align 8
  %154 = bitcast {}* %getfield176 to float**
  %arrayptr193631 = load float*, float** %154, align 8
  %155 = bitcast {}* %getfield183 to {}**
  %arraysize_ptr195 = getelementptr inbounds {}*, {}** %155, i64 3
  %156 = bitcast {}** %arraysize_ptr195 to i64*
  %arraysize196 = load i64, i64* %156, align 8
  %157 = mul i64 %arraysize196, %41
  %158 = bitcast {}* %getfield183 to float**
  %arrayptr199632 = load float*, float** %158, align 8
  %min.iters.check1465 = icmp ult i64 %arraylen178, 16
  br i1 %min.iters.check1465, label %scalar.ph1464, label %vector.ph1466

vector.ph1466:                                    ; preds = %L259.lr.ph
  %n.vec1468 = and i64 %arraylen178, 9223372036854775792
  %broadcast.splatinsert1478 = insertelement <8 x float> poison, float %147, i64 0
  %broadcast.splat1479 = shufflevector <8 x float> %broadcast.splatinsert1478, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1471

vector.body1471:                                  ; preds = %vector.body1471, %vector.ph1466
  %index1472 = phi i64 [ 0, %vector.ph1466 ], [ %index.next1482, %vector.body1471 ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1466 ], [ %174, %vector.body1471 ]
  %vec.phi1473 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1466 ], [ %175, %vector.body1471 ]
  %159 = getelementptr inbounds float, float* %arrayptr193631, i64 %index1472
  %160 = bitcast float* %159 to <8 x float>*
  %wide.load1474 = load <8 x float>, <8 x float>* %160, align 4
  %161 = getelementptr inbounds float, float* %159, i64 8
  %162 = bitcast float* %161 to <8 x float>*
  %wide.load1475 = load <8 x float>, <8 x float>* %162, align 4
  %163 = add i64 %157, %index1472
  %164 = getelementptr inbounds float, float* %arrayptr199632, i64 %163
  %165 = bitcast float* %164 to <8 x float>*
  %wide.load1476 = load <8 x float>, <8 x float>* %165, align 4
  %166 = getelementptr inbounds float, float* %164, i64 8
  %167 = bitcast float* %166 to <8 x float>*
  %wide.load1477 = load <8 x float>, <8 x float>* %167, align 4
  %168 = fmul <8 x float> %broadcast.splat1479, %wide.load1476
  %169 = fmul <8 x float> %broadcast.splat1479, %wide.load1477
  %170 = fsub <8 x float> %wide.load1474, %168
  %171 = fsub <8 x float> %wide.load1475, %169
  %172 = fmul contract <8 x float> %170, %170
  %173 = fmul contract <8 x float> %171, %171
  %174 = fadd reassoc contract <8 x float> %vec.phi, %172
  %175 = fadd reassoc contract <8 x float> %vec.phi1473, %173
  %index.next1482 = add nuw i64 %index1472, 16
  %176 = icmp eq i64 %index.next1482, %n.vec1468
  br i1 %176, label %middle.block1463, label %vector.body1471

middle.block1463:                                 ; preds = %vector.body1471
  %bin.rdx = fadd reassoc contract <8 x float> %175, %174
  %177 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n1470 = icmp eq i64 %arraylen178, %n.vec1468
  br i1 %cmp.n1470, label %L282, label %scalar.ph1464

scalar.ph1464:                                    ; preds = %middle.block1463, %L259.lr.ph
  %bc.resume.val1469 = phi i64 [ %n.vec1468, %middle.block1463 ], [ 0, %L259.lr.ph ]
  %bc.merge.rdx = phi float [ %177, %middle.block1463 ], [ 0.000000e+00, %L259.lr.ph ]
  br label %L259

L259:                                             ; preds = %L259, %scalar.ph1464
  %value_phi191870 = phi i64 [ %bc.resume.val1469, %scalar.ph1464 ], [ %185, %L259 ]
  %value_phi190869 = phi float [ %bc.merge.rdx, %scalar.ph1464 ], [ %184, %L259 ]
  %178 = getelementptr inbounds float, float* %arrayptr193631, i64 %value_phi191870
  %arrayref194 = load float, float* %178, align 4
  %179 = add i64 %157, %value_phi191870
  %180 = getelementptr inbounds float, float* %arrayptr199632, i64 %179
  %arrayref200 = load float, float* %180, align 4
  %181 = fmul float %147, %arrayref200
  %182 = fsub float %arrayref194, %181
  %183 = fmul contract float %182, %182
  %184 = fadd reassoc contract float %value_phi190869, %183
  %185 = add nuw nsw i64 %value_phi191870, 1
  %exitcond1040.not = icmp eq i64 %185, %arraylen178
  br i1 %exitcond1040.not, label %L282, label %L259

L282:                                             ; preds = %L259, %middle.block1463, %L245
  %value_phi202 = phi float [ 0.000000e+00, %L245 ], [ %177, %middle.block1463 ], [ %184, %L259 ]
  %186 = fsub float %value_phi202, %value_phi202
  %187 = fcmp uno float %186, 0.000000e+00
  %188 = fcmp ugt float %138, %value_phi202
  %189 = or i1 %188, %187
  br i1 %189, label %L291, label %L293

L291:                                             ; preds = %L282
  %190 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %190, align 8
  %191 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %191, align 16
  %192 = call float @j__sqrt_offrange_step_1563({}* nonnull %1, float %value_phi82, i64 signext %arrayref)
  br label %L409

L293:                                             ; preds = %L282, %L238
  %value_phi204 = phi float [ %150, %L238 ], [ %value_phi202, %L282 ]
  %193 = fcmp uge float %value_phi204, 0.000000e+00
  br i1 %193, label %L298, label %L296

L296:                                             ; preds = %L293
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %value_phi204) #2
  unreachable

L298:                                             ; preds = %L293
  %194 = call float @llvm.sqrt.f32(float %value_phi204)
  %195 = fsub float %145, %aggregate_load_box.sroa.0.0.copyload
  %196 = fcmp uge float %195, 0.000000e+00
  br i1 %196, label %L305, label %L303

L303:                                             ; preds = %L298
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %195) #2
  unreachable

L305:                                             ; preds = %L298
  %197 = fadd float %145, %aggregate_load_box.sroa.0.0.copyload
  %198 = fcmp uge float %197, 0.000000e+00
  br i1 %198, label %L312, label %L310

L310:                                             ; preds = %L305
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %197) #2
  unreachable

L312:                                             ; preds = %L305
  %199 = call float @llvm.sqrt.f32(float %195)
  %200 = call float @llvm.sqrt.f32(float %197)
  %201 = fmul float %199, %200
  %202 = fmul float %145, %201
  %203 = fdiv float %194, %202
  %204 = fmul float %aggregate_load_box.sroa.0.0.copyload, %203
  %205 = fcmp oge float %202, 0x3810000000000000
  %206 = fcmp oge float %203, 0x3810000000000000
  %207 = fcmp ole float %203, 0x47EFFFFFE0000000
  %narrow = and i1 %206, %207
  %208 = and i1 %205, %narrow
  %209 = fcmp oge float %204, 0x3810000000000000
  %210 = fcmp ole float %204, 0x47EFFFFFE0000000
  %narrow633 = and i1 %209, %210
  %211 = and i1 %208, %narrow633
  br i1 %211, label %L346, label %L403

L346:                                             ; preds = %L312
  %212 = fneg float %204
  %.inv635 = fcmp ogt float %148, %212
  %213 = select i1 %.inv635, float %148, float %212
  %.inv636 = fcmp olt float %213, %204
  %214 = select i1 %.inv636, float %213, float %204
  %215 = fsub float %148, %214
  %216 = fadd float %215, 0.000000e+00
  br label %L409

L403:                                             ; preds = %L312
  %217 = fpext float %194 to double
  %218 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %218, align 8
  %219 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %219, align 16
  %220 = call float @j__sqrt_band_step_1562(float %148, float %145, float %aggregate_load_box.sroa.0.0.copyload, double %217, i64 signext 0)
  br label %L409

L406:                                             ; preds = %L208
  %221 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %221, align 8
  %222 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %222, align 16
  %223 = call float @j__sqrt_offrange_step_1563({}* nonnull %1, float %value_phi82, i64 signext %arrayref)
  br label %L409

L409:                                             ; preds = %L406, %L403, %L346, %L291, %L233, %L206
  %value_phi83 = phi float [ %133, %L206 ], [ %192, %L291 ], [ %220, %L403 ], [ %223, %L406 ], [ 0.000000e+00, %L233 ], [ %216, %L346 ]
  %getfield85 = load atomic {}*, {}** %40 unordered, align 8
  %224 = bitcast {}* %getfield85 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr86 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %224, i64 0, i32 1
  %arraylen87 = load i64, i64* %arraylen_ptr86, align 8
  %inbounds88 = icmp ult i64 %41, %arraylen87
  br i1 %inbounds88, label %idxend91, label %oob89

L417:                                             ; preds = %idxend91
  %getfield107 = load atomic {}*, {}** %25 unordered, align 8
  %225 = bitcast {}* %getfield107 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr109 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %225, i64 0, i32 1
  %arraylen110 = load i64, i64* %arraylen_ptr109, align 8
  %.not617 = icmp ult i64 %41, %arraylen110
  br i1 %.not617, label %L431, label %L428

L428:                                             ; preds = %L417
  store i64 %arrayref, i64* %30, align 8
  store {}* %getfield107, {}** %19, align 16
  call void @j_throw_boundserror_1559({}* nonnull %getfield107, [1 x i64]* nocapture readonly %newstruct108) #2
  unreachable

L431:                                             ; preds = %L417
  %226 = bitcast {}* %getfield107 to i64**
  %arrayptr115618 = load i64*, i64** %226, align 8
  %227 = getelementptr inbounds i64, i64* %arrayptr115618, i64 %41
  %arrayref116 = load i64, i64* %227, align 8
  %.not619 = icmp eq i64 %arrayref116, 0
  br i1 %.not619, label %L439, label %L436

L436:                                             ; preds = %L431
  %228 = bitcast {}* %0 to float***
  %getfield1181800 = load atomic float**, float*** %228 unordered, align 8
  %229 = add i64 %arrayref116, -1
  %arrayptr120620 = load float*, float** %getfield1181800, align 8
  %230 = getelementptr inbounds float, float* %arrayptr120620, i64 %229
  store float %value_phi83, float* %230, align 4
  br label %L456

L439:                                             ; preds = %L431
  %231 = fcmp oeq float %value_phi83, 0.000000e+00
  br i1 %231, label %L456, label %L442

L442:                                             ; preds = %L439
  %232 = load i64, i64* %32, align 8
  %233 = add i64 %232, 1
  store i64 %233, i64* %32, align 8
  %getfield143 = load atomic {}*, {}** %27 unordered, align 8
  %234 = bitcast {}* %getfield143 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr144 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %234, i64 0, i32 1
  %arraylen145 = load i64, i64* %arraylen_ptr144, align 8
  %inbounds146 = icmp ult i64 %232, %arraylen145
  br i1 %inbounds146, label %idxend149, label %oob147

L456:                                             ; preds = %idxend169, %L439, %L436
  %getfield122 = load atomic {}*, {}** %39 unordered, align 8
  %235 = bitcast {}* %getfield122 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr125 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %235, i64 0, i32 1
  %arraylen126 = load i64, i64* %arraylen_ptr125, align 8
  %.not621 = icmp eq i64 %arraylen126, 0
  br i1 %.not621, label %L493, label %L469.lr.ph

L469.lr.ph:                                       ; preds = %L456
  %getfield124 = load atomic {}*, {}** %37 unordered, align 8
  %236 = bitcast {}* %getfield122 to float**
  %arrayptr131623 = load float*, float** %236, align 8
  %237 = bitcast {}* %getfield124 to {}**
  %arraysize_ptr133 = getelementptr inbounds {}*, {}** %237, i64 3
  %238 = bitcast {}** %arraysize_ptr133 to i64*
  %arraysize134 = load i64, i64* %238, align 8
  %239 = mul i64 %arraysize134, %41
  %240 = bitcast {}* %getfield124 to float**
  %arrayptr137624 = load float*, float** %240, align 8
  %min.iters.check = icmp ult i64 %arraylen126, 32
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L469.lr.ph
  %scevgep = getelementptr float, float* %arrayptr131623, i64 %arraylen126
  %scevgep1446 = getelementptr float, float* %arrayptr137624, i64 %239
  %241 = add i64 %arraylen126, %239
  %scevgep1448 = getelementptr float, float* %arrayptr137624, i64 %241
  %bound0 = icmp ult float* %arrayptr131623, %scevgep1448
  %bound1 = icmp ult float* %scevgep1446, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen126, 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %553, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %242 = getelementptr inbounds float, float* %arrayptr131623, i64 %index
  %243 = bitcast float* %242 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %243, align 4
  %244 = getelementptr inbounds float, float* %242, i64 8
  %245 = bitcast float* %244 to <8 x float>*
  %wide.load1450 = load <8 x float>, <8 x float>* %245, align 4
  %246 = getelementptr inbounds float, float* %242, i64 16
  %247 = bitcast float* %246 to <8 x float>*
  %wide.load1451 = load <8 x float>, <8 x float>* %247, align 4
  %248 = getelementptr inbounds float, float* %242, i64 24
  %249 = bitcast float* %248 to <8 x float>*
  %wide.load1452 = load <8 x float>, <8 x float>* %249, align 4
  %250 = add i64 %239, %index
  %251 = getelementptr inbounds float, float* %arrayptr137624, i64 %250
  %252 = bitcast float* %251 to <8 x float>*
  %wide.load1453 = load <8 x float>, <8 x float>* %252, align 4
  %253 = getelementptr inbounds float, float* %251, i64 8
  %254 = bitcast float* %253 to <8 x float>*
  %wide.load1454 = load <8 x float>, <8 x float>* %254, align 4
  %255 = getelementptr inbounds float, float* %251, i64 16
  %256 = bitcast float* %255 to <8 x float>*
  %wide.load1455 = load <8 x float>, <8 x float>* %256, align 4
  %257 = getelementptr inbounds float, float* %251, i64 24
  %258 = bitcast float* %257 to <8 x float>*
  %wide.load1456 = load <8 x float>, <8 x float>* %258, align 4
  %259 = fmul <8 x float> %broadcast.splat, %wide.load1453
  %260 = fmul <8 x float> %broadcast.splat, %wide.load1454
  %261 = fmul <8 x float> %broadcast.splat, %wide.load1455
  %262 = fmul <8 x float> %broadcast.splat, %wide.load1456
  %263 = fsub <8 x float> %wide.load, %259
  %264 = fsub <8 x float> %wide.load1450, %260
  %265 = fsub <8 x float> %wide.load1451, %261
  %266 = fsub <8 x float> %wide.load1452, %262
  store <8 x float> %263, <8 x float>* %243, align 4
  store <8 x float> %264, <8 x float>* %245, align 4
  store <8 x float> %265, <8 x float>* %247, align 4
  store <8 x float> %266, <8 x float>* %249, align 4
  %index.next = add nuw i64 %index, 32
  %267 = icmp eq i64 %index.next, %n.vec
  br i1 %267, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen126, %n.vec
  br i1 %cmp.n, label %L493, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L469.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L469.lr.ph ], [ 0, %vector.memcheck ]
  br label %L469

L469:                                             ; preds = %L469, %scalar.ph
  %value_phi129873 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %273, %L469 ]
  %268 = getelementptr inbounds float, float* %arrayptr131623, i64 %value_phi129873
  %arrayref132 = load float, float* %268, align 4
  %269 = add i64 %239, %value_phi129873
  %270 = getelementptr inbounds float, float* %arrayptr137624, i64 %269
  %arrayref138 = load float, float* %270, align 4
  %271 = fmul float %553, %arrayref138
  %272 = fsub float %arrayref132, %271
  store float %272, float* %268, align 4
  %273 = add nuw nsw i64 %value_phi129873, 1
  %exitcond1041.not = icmp eq i64 %273, %arraylen126
  br i1 %exitcond1041.not, label %L493, label %L469

L491:                                             ; preds = %L175
  call void @j__refuse_curvature_1564(i64 signext %arrayref) #2
  unreachable

L493:                                             ; preds = %idxend91, %L469, %middle.block, %L456
  %arrayref936 = phi i64 [ %arrayref, %L456 ], [ %arrayref937, %idxend91 ], [ %arrayref, %middle.block ], [ %arrayref, %L469 ]
  %274 = call float @llvm.fabs.f32(float %553)
  %275 = fcmp oeq float %553, 0.000000e+00
  %or.cond = select i1 %.not614, i1 true, i1 %275
  br i1 %or.cond, label %L504, label %L499

L499:                                             ; preds = %L493
  %getfield96 = load atomic {}*, {}** %23 unordered, align 8
  %276 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %276, align 8
  store {}* %getfield96, {}** %19, align 16
  %277 = call float @j_coordinate_scale_1558({}* nonnull %getfield96, {}* nonnull %0, i64 signext %arrayref)
  %278 = fmul float %274, %277
  br label %L504

L504:                                             ; preds = %L499, %L493
  %value_phi97 = phi float [ %278, %L499 ], [ %274, %L493 ]
  %279 = fsub float %value_phi97, %value_phi97
  %280 = fcmp uno float %279, 0.000000e+00
  br i1 %280, label %L510, label %L513

L510:                                             ; preds = %L504
  store {}* inttoptr (i64 135794562993360 to {}*), {}** %6, align 8
  %281 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %281)
  unreachable

L513:                                             ; preds = %L504
  %.inv615 = fcmp olt float %value_phi7, %value_phi97
  %282 = select i1 %.inv615, float %value_phi97, float %value_phi7
  %.not616.not = icmp eq i64 %value_phi5, %value_phi
  %283 = add nuw i64 %value_phi5, 1
  br i1 %.not616.not, label %L1051.loopexit691, label %L22

L530:                                             ; preds = %top
  %unbox262 = load i64, i64* %14, align 8
  %284 = call i64 @llvm.smax.i64(i64 %unbox262, i64 0)
  %285 = icmp slt i64 %unbox262, 1
  br i1 %285, label %L1051, label %L546.preheader

L546.preheader:                                   ; preds = %L530
  %286 = bitcast {}* %1 to {}**
  %287 = bitcast {}* %0 to i8*
  %getfield_addr347 = getelementptr inbounds i8, i8* %287, i64 16
  %288 = bitcast i8* %getfield_addr347 to {}**
  %289 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct349, i64 0, i64 0
  %290 = bitcast {}* %0 to {}**
  %291 = bitcast {}* %1 to i8*
  %292 = getelementptr inbounds i8, i8* %291, i64 8
  %aggregate_load_box453.sroa.0.0..sroa_idx = bitcast i8* %292 to float*
  %293 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct382, i64 0, i64 0
  %294 = getelementptr inbounds i8, i8* %287, i64 24
  %295 = bitcast i8* %294 to i64*
  %getfield_addr426 = getelementptr inbounds i8, i8* %287, i64 8
  %296 = bitcast i8* %getfield_addr426 to {}**
  %297 = and i8 %4, 1
  %.not657 = icmp eq i8 %297, 0
  br label %L546

L546:                                             ; preds = %L1036, %L546.preheader
  %indvar = phi i64 [ 0, %L546.preheader ], [ %indvar.next, %L1036 ]
  %value_phi267998 = phi i64 [ undef, %L546.preheader ], [ %value_phi267997, %L1036 ]
  %value_phi267 = phi i64 [ 1, %L546.preheader ], [ %543, %L1036 ]
  %value_phi269 = phi float [ 0.000000e+00, %L546.preheader ], [ %542, %L1036 ]
  %298 = shl i64 %indvar, 2
  %getfield272 = load atomic {}*, {}** %286 unordered, align 8
  %299 = bitcast {}* %getfield272 to {}**
  %getfield274 = load atomic {}*, {}** %299 unordered, align 8
  %300 = bitcast {}* %getfield272 to i8*
  %getfield_addr275 = getelementptr inbounds i8, i8* %300, i64 24
  %301 = bitcast i8* %getfield_addr275 to {}**
  %getfield276 = load atomic {}*, {}** %301 unordered, align 8
  %getfield_addr277 = getelementptr inbounds i8, i8* %300, i64 32
  %302 = bitcast i8* %getfield_addr277 to {}**
  %getfield278 = load atomic {}*, {}** %302 unordered, align 8
  %303 = add nsw i64 %value_phi267, -1
  %304 = bitcast {}* %getfield278 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr279 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %304, i64 0, i32 1
  %arraylen280 = load i64, i64* %arraylen_ptr279, align 8
  %inbounds281 = icmp ult i64 %303, %arraylen280
  br i1 %inbounds281, label %idxend284, label %oob282

L566:                                             ; preds = %idxend284
  br i1 %.not683, label %L650, label %L580.lr.ph

L580.lr.ph:                                       ; preds = %L566
  %305 = bitcast {}* %getfield274 to {}**
  %arraysize_ptr296 = getelementptr inbounds {}*, {}** %305, i64 3
  %306 = bitcast {}** %arraysize_ptr296 to i64*
  %arraysize297 = load i64, i64* %306, align 8
  %307 = mul i64 %arraysize297, %303
  %308 = bitcast {}* %getfield274 to float**
  %arrayptr300647 = load float*, float** %308, align 8
  %309 = bitcast {}* %getfield276 to float**
  %arrayptr303648 = load float*, float** %309, align 8
  %min.iters.check1611 = icmp ult i64 %arraylen517, 8
  br i1 %min.iters.check1611, label %scalar.ph1610, label %vector.ph1612

vector.ph1612:                                    ; preds = %L580.lr.ph
  %n.vec1614 = and i64 %arraylen517, 9223372036854775800
  br label %vector.body1617

vector.body1617:                                  ; preds = %vector.body1617, %vector.ph1612
  %index1618 = phi i64 [ 0, %vector.ph1612 ], [ %index.next1624, %vector.body1617 ]
  %vec.phi1619 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %316, %vector.body1617 ]
  %vec.phi1620 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %318, %vector.body1617 ]
  %vec.phi1621 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %320, %vector.body1617 ]
  %310 = add i64 %307, %index1618
  %311 = getelementptr inbounds float, float* %arrayptr300647, i64 %310
  %312 = bitcast float* %311 to <8 x float>*
  %wide.load1622 = load <8 x float>, <8 x float>* %312, align 4
  %313 = getelementptr inbounds float, float* %arrayptr303648, i64 %index1618
  %314 = bitcast float* %313 to <8 x float>*
  %wide.load1623 = load <8 x float>, <8 x float>* %314, align 4
  %315 = fmul contract <8 x float> %wide.load1622, %wide.load1622
  %316 = fadd reassoc contract <8 x float> %vec.phi1619, %315
  %317 = fmul contract <8 x float> %wide.load1622, %wide.load1623
  %318 = fadd reassoc contract <8 x float> %vec.phi1620, %317
  %319 = fmul contract <8 x float> %wide.load1623, %wide.load1623
  %320 = fadd reassoc contract <8 x float> %vec.phi1621, %319
  %index.next1624 = add nuw i64 %index1618, 8
  %321 = icmp eq i64 %index.next1624, %n.vec1614
  br i1 %321, label %middle.block1609, label %vector.body1617

middle.block1609:                                 ; preds = %vector.body1617
  %322 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %320)
  %323 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %318)
  %324 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %316)
  %cmp.n1616 = icmp eq i64 %arraylen517, %n.vec1614
  br i1 %cmp.n1616, label %L650, label %scalar.ph1610

scalar.ph1610:                                    ; preds = %middle.block1609, %L580.lr.ph
  %bc.resume.val1615 = phi i64 [ %n.vec1614, %middle.block1609 ], [ 0, %L580.lr.ph ]
  %bc.merge.rdx1625 = phi float [ %324, %middle.block1609 ], [ 0.000000e+00, %L580.lr.ph ]
  %bc.merge.rdx1626 = phi float [ %323, %middle.block1609 ], [ 0.000000e+00, %L580.lr.ph ]
  %bc.merge.rdx1627 = phi float [ %322, %middle.block1609 ], [ 0.000000e+00, %L580.lr.ph ]
  br label %L580

L580:                                             ; preds = %L580, %scalar.ph1610
  %value_phi295878 = phi float [ %bc.merge.rdx1625, %scalar.ph1610 ], [ %329, %L580 ]
  %value_phi294877 = phi i64 [ %bc.resume.val1615, %scalar.ph1610 ], [ %334, %L580 ]
  %value_phi293876 = phi float [ %bc.merge.rdx1626, %scalar.ph1610 ], [ %331, %L580 ]
  %value_phi292875 = phi float [ %bc.merge.rdx1627, %scalar.ph1610 ], [ %333, %L580 ]
  %325 = add i64 %307, %value_phi294877
  %326 = getelementptr inbounds float, float* %arrayptr300647, i64 %325
  %arrayref301 = load float, float* %326, align 4
  %327 = getelementptr inbounds float, float* %arrayptr303648, i64 %value_phi294877
  %arrayref304 = load float, float* %327, align 4
  %328 = fmul contract float %arrayref301, %arrayref301
  %329 = fadd reassoc contract float %value_phi295878, %328
  %330 = fmul contract float %arrayref301, %arrayref304
  %331 = fadd reassoc contract float %value_phi293876, %330
  %332 = fmul contract float %arrayref304, %arrayref304
  %333 = fadd reassoc contract float %value_phi292875, %332
  %334 = add nuw nsw i64 %value_phi294877, 1
  %exitcond1042.not = icmp eq i64 %334, %arraylen517
  br i1 %exitcond1042.not, label %L650, label %L580

L609:                                             ; preds = %idxend284
  br i1 %.not683, label %L650, label %L622.lr.ph

L622.lr.ph:                                       ; preds = %L609
  %335 = bitcast {}* %getfield274 to {}**
  %arraysize_ptr523 = getelementptr inbounds {}*, {}** %335, i64 3
  %336 = bitcast {}** %arraysize_ptr523 to i64*
  %arraysize524 = load i64, i64* %336, align 8
  %337 = mul i64 %arraysize524, %303
  %338 = bitcast {}* %getfield274 to float**
  %arrayptr527685 = load float*, float** %338, align 8
  %339 = bitcast {}* %getfield276 to float**
  %arrayptr530686 = load float*, float** %339, align 8
  %min.iters.check1588 = icmp ult i64 %arraylen517, 16
  br i1 %min.iters.check1588, label %scalar.ph1587, label %vector.ph1589

vector.ph1589:                                    ; preds = %L622.lr.ph
  %n.vec1591 = and i64 %arraylen517, 9223372036854775792
  br label %vector.body1594

vector.body1594:                                  ; preds = %vector.body1594, %vector.ph1589
  %index1595 = phi i64 [ 0, %vector.ph1589 ], [ %index.next1604, %vector.body1594 ]
  %vec.phi1596 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %351, %vector.body1594 ]
  %vec.phi1597 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %352, %vector.body1594 ]
  %vec.phi1598 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %355, %vector.body1594 ]
  %vec.phi1599 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %356, %vector.body1594 ]
  %340 = add i64 %337, %index1595
  %341 = getelementptr inbounds float, float* %arrayptr527685, i64 %340
  %342 = bitcast float* %341 to <8 x float>*
  %wide.load1600 = load <8 x float>, <8 x float>* %342, align 4
  %343 = getelementptr inbounds float, float* %341, i64 8
  %344 = bitcast float* %343 to <8 x float>*
  %wide.load1601 = load <8 x float>, <8 x float>* %344, align 4
  %345 = getelementptr inbounds float, float* %arrayptr530686, i64 %index1595
  %346 = bitcast float* %345 to <8 x float>*
  %wide.load1602 = load <8 x float>, <8 x float>* %346, align 4
  %347 = getelementptr inbounds float, float* %345, i64 8
  %348 = bitcast float* %347 to <8 x float>*
  %wide.load1603 = load <8 x float>, <8 x float>* %348, align 4
  %349 = fmul contract <8 x float> %wide.load1600, %wide.load1602
  %350 = fmul contract <8 x float> %wide.load1601, %wide.load1603
  %351 = fadd reassoc contract <8 x float> %vec.phi1596, %349
  %352 = fadd reassoc contract <8 x float> %vec.phi1597, %350
  %353 = fmul contract <8 x float> %wide.load1602, %wide.load1602
  %354 = fmul contract <8 x float> %wide.load1603, %wide.load1603
  %355 = fadd reassoc contract <8 x float> %vec.phi1598, %353
  %356 = fadd reassoc contract <8 x float> %vec.phi1599, %354
  %index.next1604 = add nuw i64 %index1595, 16
  %357 = icmp eq i64 %index.next1604, %n.vec1591
  br i1 %357, label %middle.block1586, label %vector.body1594

middle.block1586:                                 ; preds = %vector.body1594
  %bin.rdx1607 = fadd reassoc contract <8 x float> %356, %355
  %358 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1607)
  %bin.rdx1605 = fadd reassoc contract <8 x float> %352, %351
  %359 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1605)
  %cmp.n1593 = icmp eq i64 %arraylen517, %n.vec1591
  br i1 %cmp.n1593, label %L650, label %scalar.ph1587

scalar.ph1587:                                    ; preds = %middle.block1586, %L622.lr.ph
  %bc.resume.val1592 = phi i64 [ %n.vec1591, %middle.block1586 ], [ 0, %L622.lr.ph ]
  %bc.merge.rdx1606 = phi float [ %359, %middle.block1586 ], [ 0.000000e+00, %L622.lr.ph ]
  %bc.merge.rdx1608 = phi float [ %358, %middle.block1586 ], [ 0.000000e+00, %L622.lr.ph ]
  br label %L622

L622:                                             ; preds = %L622, %scalar.ph1587
  %value_phi522885 = phi i64 [ %bc.resume.val1592, %scalar.ph1587 ], [ %367, %L622 ]
  %value_phi521884 = phi float [ %bc.merge.rdx1606, %scalar.ph1587 ], [ %364, %L622 ]
  %value_phi520883 = phi float [ %bc.merge.rdx1608, %scalar.ph1587 ], [ %366, %L622 ]
  %360 = add i64 %337, %value_phi522885
  %361 = getelementptr inbounds float, float* %arrayptr527685, i64 %360
  %arrayref528 = load float, float* %361, align 4
  %362 = getelementptr inbounds float, float* %arrayptr530686, i64 %value_phi522885
  %arrayref531 = load float, float* %362, align 4
  %363 = fmul contract float %arrayref528, %arrayref531
  %364 = fadd reassoc contract float %value_phi521884, %363
  %365 = fmul contract float %arrayref531, %arrayref531
  %366 = fadd reassoc contract float %value_phi520883, %365
  %367 = add nuw nsw i64 %value_phi522885, 1
  %exitcond1043.not = icmp eq i64 %367, %arraylen517
  br i1 %exitcond1043.not, label %L650, label %L622

L650:                                             ; preds = %L622, %middle.block1586, %L609, %L580, %middle.block1609, %L566
  %value_phi312 = phi float [ 0.000000e+00, %L566 ], [ 0.000000e+00, %L609 ], [ %358, %middle.block1586 ], [ %322, %middle.block1609 ], [ %366, %L622 ], [ %333, %L580 ]
  %value_phi313 = phi float [ 0.000000e+00, %L566 ], [ 0.000000e+00, %L609 ], [ %359, %middle.block1586 ], [ %323, %middle.block1609 ], [ %364, %L622 ], [ %331, %L580 ]
  %value_phi314 = phi float [ 0.000000e+00, %L566 ], [ %arrayref287, %L609 ], [ %arrayref287, %middle.block1586 ], [ %324, %middle.block1609 ], [ %arrayref287, %L622 ], [ %329, %L580 ]
  %368 = fsub float %value_phi312, %value_phi312
  %369 = fcmp uno float %368, 0.000000e+00
  br i1 %369, label %L655, label %L657

L655:                                             ; preds = %L650
  %370 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield272, {}** %370, align 8
  %371 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield276, {}** %371, align 16
  call void @j__check_residual_1565({}* nonnull %getfield276, i64 signext %value_phi267)
  br label %L657

L657:                                             ; preds = %L655, %L650
  %372 = fcmp une float %value_phi314, 0.000000e+00
  br i1 %372, label %L698, label %L659

L659:                                             ; preds = %L657
  %getfield316 = load atomic {}*, {}** %299 unordered, align 8
  %373 = bitcast {}* %getfield316 to {}**
  %arraysize_ptr317 = getelementptr inbounds {}*, {}** %373, i64 3
  %374 = bitcast {}** %arraysize_ptr317 to i64*
  %arraysize318 = load i64, i64* %374, align 8
  %.not649.not = icmp eq i64 %arraysize318, 0
  br i1 %.not649.not, label %L698, label %L672.preheader

L672.preheader:                                   ; preds = %L659
  %arraysize_ptr332 = getelementptr inbounds {}*, {}** %373, i64 4
  %375 = bitcast {}** %arraysize_ptr332 to i64*
  %arraysize333 = load i64, i64* %375, align 8
  %inbounds334 = icmp ult i64 %303, %arraysize333
  %376 = mul i64 %arraysize318, %303
  %377 = bitcast {}* %getfield316 to float**
  %arrayptr339651 = load float*, float** %377, align 8
  %inbounds334.fr = freeze i1 %inbounds334
  br i1 %inbounds334.fr, label %ib330.us, label %oob335

ib330.us:                                         ; preds = %L678.us, %L672.preheader
  %value_phi323.us = phi i64 [ %382, %L678.us ], [ 1, %L672.preheader ]
  %378 = add nsw i64 %value_phi323.us, -1
  %379 = add i64 %376, %378
  %380 = getelementptr inbounds float, float* %arrayptr339651, i64 %379
  %arrayref340.us = load float, float* %380, align 4
  %381 = fcmp une float %arrayref340.us, 0.000000e+00
  br i1 %381, label %L694.split.us, label %L678.us

L678.us:                                          ; preds = %ib330.us
  %382 = add nuw nsw i64 %value_phi323.us, 1
  %383 = icmp ult i64 %value_phi323.us, %arraysize318
  br i1 %383, label %ib330.us, label %L698

L694.split.us:                                    ; preds = %ib330.us
  store {}* inttoptr (i64 135794568225424 to {}*), {}** %6, align 8
  %384 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %384)
  unreachable

L698:                                             ; preds = %L678.us, %L659, %L657
  %385 = fsub float %value_phi314, %value_phi314
  %386 = fcmp uno float %385, 0.000000e+00
  br i1 %386, label %L1014, label %L703

L703:                                             ; preds = %L698
  %getfield348 = load atomic {}*, {}** %288 unordered, align 8
  %387 = bitcast {}* %getfield348 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr350 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %387, i64 0, i32 1
  %arraylen351 = load i64, i64* %arraylen_ptr350, align 8
  %.not653 = icmp ult i64 %303, %arraylen351
  br i1 %.not653, label %L717, label %L714

L714:                                             ; preds = %L703
  store i64 %value_phi267, i64* %289, align 8
  %388 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield348, {}** %388, align 16
  call void @j_throw_boundserror_1559({}* nonnull %getfield348, [1 x i64]* nocapture readonly %newstruct349) #2
  unreachable

L717:                                             ; preds = %L703
  %389 = bitcast {}* %getfield348 to i64**
  %arrayptr356654 = load i64*, i64** %389, align 8
  %390 = getelementptr inbounds i64, i64* %arrayptr356654, i64 %303
  %arrayref357 = load i64, i64* %390, align 8
  %.not655 = icmp eq i64 %arrayref357, 0
  br i1 %.not655, label %L727, label %L722

L722:                                             ; preds = %L717
  %391 = bitcast {}* %0 to float***
  %getfield5081801 = load atomic float**, float*** %391 unordered, align 8
  %392 = add i64 %arrayref357, -1
  %arrayptr510682 = load float*, float** %getfield5081801, align 8
  %393 = getelementptr inbounds float, float* %arrayptr510682, i64 %392
  %arrayref511 = load float, float* %393, align 4
  br label %L727

L727:                                             ; preds = %L722, %L717
  %value_phi358 = phi float [ %arrayref511, %L722 ], [ 0.000000e+00, %L717 ]
  br i1 %372, label %L731, label %L729

L729:                                             ; preds = %L727
  %394 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield272, {}** %394, align 8
  %395 = call float @j__coordinate_minimizer_1557({ double }* nocapture nonnull readonly %2, float %value_phi358, i64 signext %value_phi267)
  br label %L932

L731:                                             ; preds = %L727
  %getfield448 = load atomic {}*, {}** %286 unordered, align 8
  %396 = bitcast {}* %getfield448 to i8*
  %getfield_addr449 = getelementptr inbounds i8, i8* %396, i64 24
  %397 = bitcast i8* %getfield_addr449 to {}**
  %getfield450 = load atomic {}*, {}** %397 unordered, align 8
  %398 = bitcast {}* %getfield450 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr451 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %398, i64 0, i32 1
  %arraylen452 = load i64, i64* %arraylen_ptr451, align 8
  %399 = sitofp i64 %arraylen452 to float
  %400 = fmul float %399, 0x3980000000000000
  %401 = fcmp ole float %400, %value_phi314
  %402 = fcmp ord float %368, 0.000000e+00
  %403 = fcmp ole float %400, %value_phi312
  %404 = and i1 %402, %403
  %405 = and i1 %401, %404
  br i1 %405, label %L750, label %L929

L750:                                             ; preds = %L731
  %aggregate_load_box453.sroa.0.0.copyload = load float, float* %aggregate_load_box453.sroa.0.0..sroa_idx, align 1
  %406 = fcmp uge float %value_phi314, 0.000000e+00
  br i1 %406, label %L756, label %L754

L754:                                             ; preds = %L750
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %value_phi314) #2
  unreachable

L756:                                             ; preds = %L750
  %407 = call float @llvm.sqrt.f32(float %value_phi314)
  %408 = fcmp ugt float %407, %aggregate_load_box453.sroa.0.0.copyload
  br i1 %408, label %L761, label %L932

L761:                                             ; preds = %L756
  %409 = fdiv float %value_phi313, %value_phi314
  %410 = fadd float %409, %value_phi358
  %411 = fmul float %value_phi313, %409
  %412 = fsub float %value_phi312, %411
  %413 = fmul float %value_phi312, 6.250000e-02
  %414 = fcmp uge float %412, %413
  br i1 %414, label %L816, label %L768

L768:                                             ; preds = %L761
  %.not672 = icmp eq i64 %arraylen452, 0
  br i1 %.not672, label %L805, label %L782.lr.ph

L782.lr.ph:                                       ; preds = %L768
  %415 = bitcast {}* %getfield448 to {}**
  %getfield458 = load atomic {}*, {}** %415 unordered, align 8
  %416 = bitcast {}* %getfield450 to float**
  %arrayptr468674 = load float*, float** %416, align 8
  %417 = bitcast {}* %getfield458 to {}**
  %arraysize_ptr470 = getelementptr inbounds {}*, {}** %417, i64 3
  %418 = bitcast {}** %arraysize_ptr470 to i64*
  %arraysize471 = load i64, i64* %418, align 8
  %419 = mul i64 %arraysize471, %303
  %420 = bitcast {}* %getfield458 to float**
  %arrayptr474675 = load float*, float** %420, align 8
  %min.iters.check1565 = icmp ult i64 %arraylen452, 16
  br i1 %min.iters.check1565, label %scalar.ph1564, label %vector.ph1566

vector.ph1566:                                    ; preds = %L782.lr.ph
  %n.vec1568 = and i64 %arraylen452, 9223372036854775792
  %broadcast.splatinsert1579 = insertelement <8 x float> poison, float %409, i64 0
  %broadcast.splat1580 = shufflevector <8 x float> %broadcast.splatinsert1579, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1571

vector.body1571:                                  ; preds = %vector.body1571, %vector.ph1566
  %index1572 = phi i64 [ 0, %vector.ph1566 ], [ %index.next1583, %vector.body1571 ]
  %vec.phi1573 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1566 ], [ %436, %vector.body1571 ]
  %vec.phi1574 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1566 ], [ %437, %vector.body1571 ]
  %421 = getelementptr inbounds float, float* %arrayptr468674, i64 %index1572
  %422 = bitcast float* %421 to <8 x float>*
  %wide.load1575 = load <8 x float>, <8 x float>* %422, align 4
  %423 = getelementptr inbounds float, float* %421, i64 8
  %424 = bitcast float* %423 to <8 x float>*
  %wide.load1576 = load <8 x float>, <8 x float>* %424, align 4
  %425 = add i64 %419, %index1572
  %426 = getelementptr inbounds float, float* %arrayptr474675, i64 %425
  %427 = bitcast float* %426 to <8 x float>*
  %wide.load1577 = load <8 x float>, <8 x float>* %427, align 4
  %428 = getelementptr inbounds float, float* %426, i64 8
  %429 = bitcast float* %428 to <8 x float>*
  %wide.load1578 = load <8 x float>, <8 x float>* %429, align 4
  %430 = fmul <8 x float> %broadcast.splat1580, %wide.load1577
  %431 = fmul <8 x float> %broadcast.splat1580, %wide.load1578
  %432 = fsub <8 x float> %wide.load1575, %430
  %433 = fsub <8 x float> %wide.load1576, %431
  %434 = fmul contract <8 x float> %432, %432
  %435 = fmul contract <8 x float> %433, %433
  %436 = fadd reassoc contract <8 x float> %vec.phi1573, %434
  %437 = fadd reassoc contract <8 x float> %vec.phi1574, %435
  %index.next1583 = add nuw i64 %index1572, 16
  %438 = icmp eq i64 %index.next1583, %n.vec1568
  br i1 %438, label %middle.block1563, label %vector.body1571

middle.block1563:                                 ; preds = %vector.body1571
  %bin.rdx1584 = fadd reassoc contract <8 x float> %437, %436
  %439 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1584)
  %cmp.n1570 = icmp eq i64 %arraylen452, %n.vec1568
  br i1 %cmp.n1570, label %L805, label %scalar.ph1564

scalar.ph1564:                                    ; preds = %middle.block1563, %L782.lr.ph
  %bc.resume.val1569 = phi i64 [ %n.vec1568, %middle.block1563 ], [ 0, %L782.lr.ph ]
  %bc.merge.rdx1585 = phi float [ %439, %middle.block1563 ], [ 0.000000e+00, %L782.lr.ph ]
  br label %L782

L782:                                             ; preds = %L782, %scalar.ph1564
  %value_phi466890 = phi i64 [ %bc.resume.val1569, %scalar.ph1564 ], [ %447, %L782 ]
  %value_phi465889 = phi float [ %bc.merge.rdx1585, %scalar.ph1564 ], [ %446, %L782 ]
  %440 = getelementptr inbounds float, float* %arrayptr468674, i64 %value_phi466890
  %arrayref469 = load float, float* %440, align 4
  %441 = add i64 %419, %value_phi466890
  %442 = getelementptr inbounds float, float* %arrayptr474675, i64 %441
  %arrayref475 = load float, float* %442, align 4
  %443 = fmul float %409, %arrayref475
  %444 = fsub float %arrayref469, %443
  %445 = fmul contract float %444, %444
  %446 = fadd reassoc contract float %value_phi465889, %445
  %447 = add nuw nsw i64 %value_phi466890, 1
  %exitcond1044.not = icmp eq i64 %447, %arraylen452
  br i1 %exitcond1044.not, label %L805, label %L782

L805:                                             ; preds = %L782, %middle.block1563, %L768
  %value_phi477 = phi float [ 0.000000e+00, %L768 ], [ %439, %middle.block1563 ], [ %446, %L782 ]
  %448 = fsub float %value_phi477, %value_phi477
  %449 = fcmp uno float %448, 0.000000e+00
  %450 = fcmp ugt float %400, %value_phi477
  %451 = or i1 %450, %449
  br i1 %451, label %L814, label %L816

L814:                                             ; preds = %L805
  %452 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield272, {}** %452, align 8
  %453 = call float @j__sqrt_offrange_step_1563({}* nonnull %1, float %value_phi358, i64 signext %value_phi267)
  br label %L932

L816:                                             ; preds = %L805, %L761
  %value_phi479 = phi float [ %412, %L761 ], [ %value_phi477, %L805 ]
  %454 = fcmp uge float %value_phi479, 0.000000e+00
  br i1 %454, label %L821, label %L819

L819:                                             ; preds = %L816
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %value_phi479) #2
  unreachable

L821:                                             ; preds = %L816
  %455 = call float @llvm.sqrt.f32(float %value_phi479)
  %456 = fsub float %407, %aggregate_load_box453.sroa.0.0.copyload
  %457 = fcmp uge float %456, 0.000000e+00
  br i1 %457, label %L828, label %L826

L826:                                             ; preds = %L821
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %456) #2
  unreachable

L828:                                             ; preds = %L821
  %458 = fadd float %407, %aggregate_load_box453.sroa.0.0.copyload
  %459 = fcmp uge float %458, 0.000000e+00
  br i1 %459, label %L835, label %L833

L833:                                             ; preds = %L828
  call void @j_throw_complex_domainerror_1560({}* inttoptr (i64 135794596555280 to {}*), float %458) #2
  unreachable

L835:                                             ; preds = %L828
  %460 = call float @llvm.sqrt.f32(float %456)
  %461 = call float @llvm.sqrt.f32(float %458)
  %462 = fmul float %460, %461
  %463 = fmul float %407, %462
  %464 = fdiv float %455, %463
  %465 = fmul float %aggregate_load_box453.sroa.0.0.copyload, %464
  %466 = fcmp oge float %463, 0x3810000000000000
  %467 = fcmp oge float %464, 0x3810000000000000
  %468 = fcmp ole float %464, 0x47EFFFFFE0000000
  %narrow676 = and i1 %467, %468
  %469 = and i1 %466, %narrow676
  %470 = fcmp oge float %465, 0x3810000000000000
  %471 = fcmp ole float %465, 0x47EFFFFFE0000000
  %narrow677 = and i1 %470, %471
  %472 = and i1 %469, %narrow677
  br i1 %472, label %L869, label %L926

L869:                                             ; preds = %L835
  %473 = fneg float %465
  %.inv679 = fcmp ogt float %410, %473
  %474 = select i1 %.inv679, float %410, float %473
  %.inv680 = fcmp olt float %474, %465
  %475 = select i1 %.inv680, float %474, float %465
  %476 = fsub float %410, %475
  %477 = fadd float %476, 0.000000e+00
  br label %L932

L926:                                             ; preds = %L835
  %478 = fpext float %455 to double
  %479 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield272, {}** %479, align 8
  %480 = call float @j__sqrt_band_step_1562(float %410, float %407, float %aggregate_load_box453.sroa.0.0.copyload, double %478, i64 signext 0)
  br label %L932

L929:                                             ; preds = %L731
  %481 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield272, {}** %481, align 8
  %482 = call float @j__sqrt_offrange_step_1563({}* nonnull %1, float %value_phi358, i64 signext %value_phi267)
  br label %L932

L932:                                             ; preds = %L929, %L926, %L869, %L814, %L756, %L729
  %value_phi359 = phi float [ %395, %L729 ], [ %453, %L814 ], [ %480, %L926 ], [ %482, %L929 ], [ 0.000000e+00, %L756 ], [ %477, %L869 ]
  %getfield361 = load atomic {}*, {}** %302 unordered, align 8
  %483 = bitcast {}* %getfield361 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr362 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %483, i64 0, i32 1
  %arraylen363 = load i64, i64* %arraylen_ptr362, align 8
  %inbounds364 = icmp ult i64 %303, %arraylen363
  br i1 %inbounds364, label %idxend367, label %oob365

L940:                                             ; preds = %idxend367
  %getfield381 = load atomic {}*, {}** %288 unordered, align 8
  %484 = bitcast {}* %getfield381 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr383 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %484, i64 0, i32 1
  %arraylen384 = load i64, i64* %arraylen_ptr383, align 8
  %.not660 = icmp ult i64 %303, %arraylen384
  br i1 %.not660, label %L954, label %L951

L951:                                             ; preds = %L940
  store i64 %value_phi267, i64* %293, align 8
  %485 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield381, {}** %485, align 16
  call void @j_throw_boundserror_1559({}* nonnull %getfield381, [1 x i64]* nocapture readonly %newstruct382) #2
  unreachable

L954:                                             ; preds = %L940
  %486 = bitcast {}* %getfield381 to i64**
  %arrayptr389661 = load i64*, i64** %486, align 8
  %487 = getelementptr inbounds i64, i64* %arrayptr389661, i64 %303
  %arrayref390 = load i64, i64* %487, align 8
  %.not662 = icmp eq i64 %arrayref390, 0
  br i1 %.not662, label %L962, label %L959

L959:                                             ; preds = %L954
  %488 = bitcast {}* %0 to float***
  %getfield3921802 = load atomic float**, float*** %488 unordered, align 8
  %489 = add i64 %arrayref390, -1
  %arrayptr394663 = load float*, float** %getfield3921802, align 8
  %490 = getelementptr inbounds float, float* %arrayptr394663, i64 %489
  store float %value_phi359, float* %490, align 4
  br label %L979

L962:                                             ; preds = %L954
  %491 = fcmp oeq float %value_phi359, 0.000000e+00
  br i1 %491, label %L979, label %L965

L965:                                             ; preds = %L962
  %492 = load i64, i64* %295, align 8
  %493 = add i64 %492, 1
  store i64 %493, i64* %295, align 8
  %getfield417 = load atomic {}*, {}** %290 unordered, align 8
  %494 = bitcast {}* %getfield417 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr418 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %494, i64 0, i32 1
  %arraylen419 = load i64, i64* %arraylen_ptr418, align 8
  %inbounds420 = icmp ult i64 %492, %arraylen419
  br i1 %inbounds420, label %idxend423, label %oob421

L979:                                             ; preds = %idxend443, %L962, %L959
  %getfield396 = load atomic {}*, {}** %301 unordered, align 8
  %495 = bitcast {}* %getfield396 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr399 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %495, i64 0, i32 1
  %arraylen400 = load i64, i64* %arraylen_ptr399, align 8
  %.not664 = icmp eq i64 %arraylen400, 0
  br i1 %.not664, label %L1016, label %L992.lr.ph

L992.lr.ph:                                       ; preds = %L979
  %getfield398 = load atomic {}*, {}** %299 unordered, align 8
  %496 = bitcast {}* %getfield396 to float**
  %arrayptr405666 = load float*, float** %496, align 8
  %497 = bitcast {}* %getfield398 to {}**
  %arraysize_ptr407 = getelementptr inbounds {}*, {}** %497, i64 3
  %498 = bitcast {}** %arraysize_ptr407 to i64*
  %arraysize408 = load i64, i64* %498, align 8
  %499 = mul i64 %arraysize408, %303
  %500 = bitcast {}* %getfield398 to float**
  %arrayptr411667 = load float*, float** %500, align 8
  %min.iters.check1538 = icmp ult i64 %arraylen400, 32
  br i1 %min.iters.check1538, label %scalar.ph1537, label %vector.memcheck1525

vector.memcheck1525:                              ; preds = %L992.lr.ph
  %arrayptr4116671529 = bitcast float* %arrayptr411667 to i8*
  %arrayptr4056661526 = bitcast float* %arrayptr405666 to i8*
  %scevgep1527 = getelementptr float, float* %arrayptr405666, i64 %arraylen400
  %scevgep15271528 = bitcast float* %scevgep1527 to i8*
  %501 = mul i64 %arraysize408, %298
  %uglygep = getelementptr i8, i8* %arrayptr4116671529, i64 %501
  %scevgep1530 = getelementptr float, float* %arrayptr411667, i64 %arraylen400
  %scevgep15301531 = bitcast float* %scevgep1530 to i8*
  %uglygep1532 = getelementptr i8, i8* %scevgep15301531, i64 %501
  %bound01533 = icmp ugt i8* %uglygep1532, %arrayptr4056661526
  %bound11534 = icmp ult i8* %uglygep, %scevgep15271528
  %found.conflict1535 = and i1 %bound01533, %bound11534
  br i1 %found.conflict1535, label %scalar.ph1537, label %vector.ph1539

vector.ph1539:                                    ; preds = %vector.memcheck1525
  %n.vec1541 = and i64 %arraylen400, 9223372036854775776
  %broadcast.splatinsert1554 = insertelement <8 x float> poison, float %567, i64 0
  %broadcast.splat1555 = shufflevector <8 x float> %broadcast.splatinsert1554, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1544

vector.body1544:                                  ; preds = %vector.body1544, %vector.ph1539
  %index1545 = phi i64 [ 0, %vector.ph1539 ], [ %index.next1562, %vector.body1544 ]
  %502 = getelementptr inbounds float, float* %arrayptr405666, i64 %index1545
  %503 = bitcast float* %502 to <8 x float>*
  %wide.load1546 = load <8 x float>, <8 x float>* %503, align 4
  %504 = getelementptr inbounds float, float* %502, i64 8
  %505 = bitcast float* %504 to <8 x float>*
  %wide.load1547 = load <8 x float>, <8 x float>* %505, align 4
  %506 = getelementptr inbounds float, float* %502, i64 16
  %507 = bitcast float* %506 to <8 x float>*
  %wide.load1548 = load <8 x float>, <8 x float>* %507, align 4
  %508 = getelementptr inbounds float, float* %502, i64 24
  %509 = bitcast float* %508 to <8 x float>*
  %wide.load1549 = load <8 x float>, <8 x float>* %509, align 4
  %510 = add i64 %499, %index1545
  %511 = getelementptr inbounds float, float* %arrayptr411667, i64 %510
  %512 = bitcast float* %511 to <8 x float>*
  %wide.load1550 = load <8 x float>, <8 x float>* %512, align 4
  %513 = getelementptr inbounds float, float* %511, i64 8
  %514 = bitcast float* %513 to <8 x float>*
  %wide.load1551 = load <8 x float>, <8 x float>* %514, align 4
  %515 = getelementptr inbounds float, float* %511, i64 16
  %516 = bitcast float* %515 to <8 x float>*
  %wide.load1552 = load <8 x float>, <8 x float>* %516, align 4
  %517 = getelementptr inbounds float, float* %511, i64 24
  %518 = bitcast float* %517 to <8 x float>*
  %wide.load1553 = load <8 x float>, <8 x float>* %518, align 4
  %519 = fmul <8 x float> %broadcast.splat1555, %wide.load1550
  %520 = fmul <8 x float> %broadcast.splat1555, %wide.load1551
  %521 = fmul <8 x float> %broadcast.splat1555, %wide.load1552
  %522 = fmul <8 x float> %broadcast.splat1555, %wide.load1553
  %523 = fsub <8 x float> %wide.load1546, %519
  %524 = fsub <8 x float> %wide.load1547, %520
  %525 = fsub <8 x float> %wide.load1548, %521
  %526 = fsub <8 x float> %wide.load1549, %522
  store <8 x float> %523, <8 x float>* %503, align 4
  store <8 x float> %524, <8 x float>* %505, align 4
  store <8 x float> %525, <8 x float>* %507, align 4
  store <8 x float> %526, <8 x float>* %509, align 4
  %index.next1562 = add nuw i64 %index1545, 32
  %527 = icmp eq i64 %index.next1562, %n.vec1541
  br i1 %527, label %middle.block1536, label %vector.body1544

middle.block1536:                                 ; preds = %vector.body1544
  %cmp.n1543 = icmp eq i64 %arraylen400, %n.vec1541
  br i1 %cmp.n1543, label %L1016, label %scalar.ph1537

scalar.ph1537:                                    ; preds = %middle.block1536, %vector.memcheck1525, %L992.lr.ph
  %bc.resume.val1542 = phi i64 [ %n.vec1541, %middle.block1536 ], [ 0, %L992.lr.ph ], [ 0, %vector.memcheck1525 ]
  br label %L992

L992:                                             ; preds = %L992, %scalar.ph1537
  %value_phi403893 = phi i64 [ %bc.resume.val1542, %scalar.ph1537 ], [ %533, %L992 ]
  %528 = getelementptr inbounds float, float* %arrayptr405666, i64 %value_phi403893
  %arrayref406 = load float, float* %528, align 4
  %529 = add i64 %499, %value_phi403893
  %530 = getelementptr inbounds float, float* %arrayptr411667, i64 %529
  %arrayref412 = load float, float* %530, align 4
  %531 = fmul float %567, %arrayref412
  %532 = fsub float %arrayref406, %531
  store float %532, float* %528, align 4
  %533 = add nuw nsw i64 %value_phi403893, 1
  %exitcond1045.not = icmp eq i64 %533, %arraylen400
  br i1 %exitcond1045.not, label %L1016, label %L992

L1014:                                            ; preds = %L698
  call void @j__refuse_curvature_1564(i64 signext %value_phi267) #2
  unreachable

L1016:                                            ; preds = %idxend367, %L992, %middle.block1536, %L979
  %value_phi267997 = phi i64 [ %value_phi267, %L979 ], [ %value_phi267998, %idxend367 ], [ %value_phi267, %middle.block1536 ], [ %value_phi267, %L992 ]
  %534 = call float @llvm.fabs.f32(float %567)
  %535 = fcmp oeq float %567, 0.000000e+00
  %or.cond1292 = select i1 %.not657, i1 true, i1 %535
  br i1 %or.cond1292, label %L1027, label %L1022

L1022:                                            ; preds = %L1016
  %getfield372 = load atomic {}*, {}** %286 unordered, align 8
  %536 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield372, {}** %536, align 16
  %537 = call float @j_coordinate_scale_1558({}* nonnull %getfield372, {}* nonnull %0, i64 signext %value_phi267)
  %538 = fmul float %534, %537
  br label %L1027

L1027:                                            ; preds = %L1022, %L1016
  %value_phi373 = phi float [ %538, %L1022 ], [ %534, %L1016 ]
  %539 = fsub float %value_phi373, %value_phi373
  %540 = fcmp uno float %539, 0.000000e+00
  br i1 %540, label %L1033, label %L1036

L1033:                                            ; preds = %L1027
  store {}* inttoptr (i64 135794562993360 to {}*), {}** %6, align 8
  %541 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %541)
  unreachable

L1036:                                            ; preds = %L1027
  %.inv658 = fcmp olt float %value_phi269, %value_phi373
  %542 = select i1 %.inv658, float %value_phi373, float %value_phi269
  %.not659.not = icmp eq i64 %value_phi267, %284
  %543 = add nuw i64 %value_phi267, 1
  %indvar.next = add i64 %indvar, 1
  br i1 %.not659.not, label %L1051.loopexit, label %L546

L1051.loopexit:                                   ; preds = %L1036
  store i64 %284, i64* %289, align 8
  store i64 %value_phi267997, i64* %293, align 8
  br label %L1051

L1051.loopexit691:                                ; preds = %L513
  store i64 %arrayref, i64* %26, align 8
  store i64 %arrayref936, i64* %30, align 8
  br label %L1051

L1051:                                            ; preds = %L1051.loopexit691, %L1051.loopexit, %L530, %L4
  %value_phi103 = phi float [ 0.000000e+00, %L4 ], [ 0.000000e+00, %L530 ], [ %542, %L1051.loopexit ], [ %282, %L1051.loopexit691 ]
  %544 = load {}*, {}** %10, align 8
  %545 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %544, {}** %545, align 8
  ret float %value_phi103

oob:                                              ; preds = %L22
  %errorbox = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L22
  %546 = bitcast {}* %getfield16 to float**
  %arrayptr18601 = load float*, float** %546, align 8
  %547 = getelementptr inbounds float, float* %arrayptr18601, i64 %41
  %arrayref19 = load float, float* %547, align 4
  %548 = fcmp ord float %arrayref19, 0.000000e+00
  %549 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr240 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %549, i64 0, i32 1
  %arraylen241 = load i64, i64* %arraylen_ptr240, align 8
  %.not639 = icmp eq i64 %arraylen241, 0
  br i1 %548, label %L86, label %L43

oob60:                                            ; preds = %L149.preheader
  %errorbox61607 = alloca [2 x i64], align 8
  %errorbox61607.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 0
  store i64 1, i64* %errorbox61607.sub, align 8
  %550 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 1
  store i64 %arrayref, i64* %550, align 8
  call void @ijl_bounds_error_ints({}* %getfield42, i64* nonnull %errorbox61607.sub, i64 2)
  unreachable

oob89:                                            ; preds = %L409
  %errorbox90 = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox90, align 8
  call void @ijl_bounds_error_ints({}* %getfield85, i64* nonnull %errorbox90, i64 1)
  unreachable

idxend91:                                         ; preds = %L409
  %551 = bitcast {}* %getfield85 to float**
  %arrayptr93613 = load float*, float** %551, align 8
  %552 = getelementptr inbounds float, float* %arrayptr93613, i64 %41
  store float %value_phi40, float* %552, align 4
  %553 = fsub float %value_phi83, %value_phi82
  %554 = fcmp une float %553, 0.000000e+00
  br i1 %554, label %L417, label %L493

oob147:                                           ; preds = %L442
  %errorbox148 = alloca i64, align 8
  store i64 %233, i64* %errorbox148, align 8
  call void @ijl_bounds_error_ints({}* %getfield143, i64* nonnull %errorbox148, i64 1)
  unreachable

idxend149:                                        ; preds = %L442
  %555 = bitcast {}* %getfield143 to float**
  %arrayptr151626 = load float*, float** %555, align 8
  %556 = getelementptr inbounds float, float* %arrayptr151626, i64 %232
  store float %value_phi83, float* %556, align 4
  %getfield153 = load atomic {}*, {}** %33 unordered, align 8
  %557 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %557, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %232, %arraylen155
  br i1 %inbounds156, label %idxend169, label %oob157

oob157:                                           ; preds = %idxend149
  %errorbox158 = alloca i64, align 8
  store i64 %233, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend169:                                        ; preds = %idxend149
  %558 = bitcast {}* %getfield153 to i64**
  %arrayptr161627 = load i64*, i64** %558, align 8
  %559 = getelementptr inbounds i64, i64* %arrayptr161627, i64 %232
  store i64 %arrayref, i64* %559, align 8
  store i64 %233, i64* %227, align 8
  br label %L456

oob282:                                           ; preds = %L546
  %errorbox283 = alloca i64, align 8
  store i64 %value_phi267, i64* %errorbox283, align 8
  call void @ijl_bounds_error_ints({}* %getfield278, i64* nonnull %errorbox283, i64 1)
  unreachable

idxend284:                                        ; preds = %L546
  %560 = bitcast {}* %getfield278 to float**
  %arrayptr286644 = load float*, float** %560, align 8
  %561 = getelementptr inbounds float, float* %arrayptr286644, i64 %303
  %arrayref287 = load float, float* %561, align 4
  %562 = fcmp ord float %arrayref287, 0.000000e+00
  %563 = bitcast {}* %getfield276 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr516 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %563, i64 0, i32 1
  %arraylen517 = load i64, i64* %arraylen_ptr516, align 8
  %.not683 = icmp eq i64 %arraylen517, 0
  br i1 %562, label %L609, label %L566

oob335:                                           ; preds = %L672.preheader
  %errorbox336650 = alloca [2 x i64], align 8
  %errorbox336650.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox336650, i64 0, i64 0
  store i64 1, i64* %errorbox336650.sub, align 8
  %564 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox336650, i64 0, i64 1
  store i64 %value_phi267, i64* %564, align 8
  call void @ijl_bounds_error_ints({}* %getfield316, i64* nonnull %errorbox336650.sub, i64 2)
  unreachable

oob365:                                           ; preds = %L932
  %errorbox366 = alloca i64, align 8
  store i64 %value_phi267, i64* %errorbox366, align 8
  call void @ijl_bounds_error_ints({}* %getfield361, i64* nonnull %errorbox366, i64 1)
  unreachable

idxend367:                                        ; preds = %L932
  %565 = bitcast {}* %getfield361 to float**
  %arrayptr369656 = load float*, float** %565, align 8
  %566 = getelementptr inbounds float, float* %arrayptr369656, i64 %303
  store float %value_phi314, float* %566, align 4
  %567 = fsub float %value_phi359, %value_phi358
  %568 = fcmp une float %567, 0.000000e+00
  br i1 %568, label %L940, label %L1016

oob421:                                           ; preds = %L965
  %errorbox422 = alloca i64, align 8
  store i64 %493, i64* %errorbox422, align 8
  call void @ijl_bounds_error_ints({}* %getfield417, i64* nonnull %errorbox422, i64 1)
  unreachable

idxend423:                                        ; preds = %L965
  %569 = bitcast {}* %getfield417 to float**
  %arrayptr425669 = load float*, float** %569, align 8
  %570 = getelementptr inbounds float, float* %arrayptr425669, i64 %492
  store float %value_phi359, float* %570, align 4
  %getfield427 = load atomic {}*, {}** %296 unordered, align 8
  %571 = bitcast {}* %getfield427 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr428 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %571, i64 0, i32 1
  %arraylen429 = load i64, i64* %arraylen_ptr428, align 8
  %inbounds430 = icmp ult i64 %492, %arraylen429
  br i1 %inbounds430, label %idxend443, label %oob431

oob431:                                           ; preds = %idxend423
  %errorbox432 = alloca i64, align 8
  store i64 %493, i64* %errorbox432, align 8
  call void @ijl_bounds_error_ints({}* %getfield427, i64* nonnull %errorbox432, i64 1)
  unreachable

idxend443:                                        ; preds = %idxend423
  %572 = bitcast {}* %getfield427 to i64**
  %arrayptr435670 = load i64*, i64** %572, align 8
  %573 = getelementptr inbounds i64, i64* %arrayptr435670, i64 %492
  store i64 %value_phi267, i64* %573, align 8
  store i64 %493, i64* %487, align 8
  br label %L979
}
