define float @"julia__sweep!_1816"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(72) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(48) %3, i8 zeroext %4, [1 x i64]* nocapture noundef nonnull readonly align 8 dereferenceable(8) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1798 = alloca [5 x {}*], align 16
  %gcframe1798.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1798 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct73 = alloca [1 x i64], align 8
  %newstruct108 = alloca [1 x i64], align 8
  %newstruct348 = alloca [1 x i64], align 8
  %newstruct381 = alloca [1 x i64], align 8
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
  br i1 %.not, label %L529, label %L4

L4:                                               ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %15, i64 8
  %18 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %18 unordered, align 8
  %unbox = load i64, i64* %14, align 8
  %19 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield, {}** %19, align 16
  %20 = call nonnull {}* @"j__shuffle!_1818"({}* nonnull %getfield, i64 signext %unbox)
  %unbox538 = load i64, i64* %14, align 8
  %.inv = icmp sgt i64 %unbox, 0
  %value_phi = select i1 %.inv, i64 %unbox538, i64 0
  %21 = icmp slt i64 %value_phi, 1
  br i1 %21, label %L1049, label %L22.preheader

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

L22:                                              ; preds = %L512, %L22.preheader
  %arrayref937 = phi i64 [ %arrayref936, %L512 ], [ undef, %L22.preheader ]
  %value_phi5 = phi i64 [ %282, %L512 ], [ 1, %L22.preheader ]
  %value_phi7 = phi float [ %281, %L512 ], [ 0.000000e+00, %L22.preheader ]
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
  %min.iters.check1508 = icmp ult i64 %arraylen240, 8
  br i1 %min.iters.check1508, label %scalar.ph1507, label %vector.ph1509

vector.ph1509:                                    ; preds = %L57.lr.ph
  %n.vec1511 = and i64 %arraylen240, 9223372036854775800
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
  %cmp.n1513 = icmp eq i64 %arraylen240, %n.vec1511
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
  %exitcond.not = icmp eq i64 %72, %arraylen240
  br i1 %exitcond.not, label %L127, label %L57

L86:                                              ; preds = %idxend
  br i1 %.not639, label %L127, label %L99.lr.ph

L99.lr.ph:                                        ; preds = %L86
  %73 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr246 = getelementptr inbounds {}*, {}** %73, i64 3
  %74 = bitcast {}** %arraysize_ptr246 to i64*
  %arraysize247 = load i64, i64* %74, align 8
  %75 = mul i64 %arraysize247, %41
  %76 = bitcast {}* %getfield12 to float**
  %arrayptr250641 = load float*, float** %76, align 8
  %77 = bitcast {}* %getfield14 to float**
  %arrayptr253642 = load float*, float** %77, align 8
  %min.iters.check1485 = icmp ult i64 %arraylen240, 16
  br i1 %min.iters.check1485, label %scalar.ph1484, label %vector.ph1486

vector.ph1486:                                    ; preds = %L99.lr.ph
  %n.vec1488 = and i64 %arraylen240, 9223372036854775792
  br label %vector.body1491

vector.body1491:                                  ; preds = %vector.body1491, %vector.ph1486
  %index1492 = phi i64 [ 0, %vector.ph1486 ], [ %index.next1501, %vector.body1491 ]
  %vec.phi1493 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %89, %vector.body1491 ]
  %vec.phi1494 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %90, %vector.body1491 ]
  %vec.phi1495 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %93, %vector.body1491 ]
  %vec.phi1496 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1486 ], [ %94, %vector.body1491 ]
  %78 = add i64 %75, %index1492
  %79 = getelementptr inbounds float, float* %arrayptr250641, i64 %78
  %80 = bitcast float* %79 to <8 x float>*
  %wide.load1497 = load <8 x float>, <8 x float>* %80, align 4
  %81 = getelementptr inbounds float, float* %79, i64 8
  %82 = bitcast float* %81 to <8 x float>*
  %wide.load1498 = load <8 x float>, <8 x float>* %82, align 4
  %83 = getelementptr inbounds float, float* %arrayptr253642, i64 %index1492
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
  %cmp.n1490 = icmp eq i64 %arraylen240, %n.vec1488
  br i1 %cmp.n1490, label %L127, label %scalar.ph1484

scalar.ph1484:                                    ; preds = %middle.block1483, %L99.lr.ph
  %bc.resume.val1489 = phi i64 [ %n.vec1488, %middle.block1483 ], [ 0, %L99.lr.ph ]
  %bc.merge.rdx1503 = phi float [ %97, %middle.block1483 ], [ 0.000000e+00, %L99.lr.ph ]
  %bc.merge.rdx1505 = phi float [ %96, %middle.block1483 ], [ 0.000000e+00, %L99.lr.ph ]
  br label %L99

L99:                                              ; preds = %L99, %scalar.ph1484
  %value_phi245865 = phi i64 [ %bc.resume.val1489, %scalar.ph1484 ], [ %105, %L99 ]
  %value_phi244864 = phi float [ %bc.merge.rdx1503, %scalar.ph1484 ], [ %102, %L99 ]
  %value_phi243863 = phi float [ %bc.merge.rdx1505, %scalar.ph1484 ], [ %104, %L99 ]
  %98 = add i64 %75, %value_phi245865
  %99 = getelementptr inbounds float, float* %arrayptr250641, i64 %98
  %arrayref251 = load float, float* %99, align 4
  %100 = getelementptr inbounds float, float* %arrayptr253642, i64 %value_phi245865
  %arrayref254 = load float, float* %100, align 4
  %101 = fmul contract float %arrayref251, %arrayref254
  %102 = fadd reassoc contract float %value_phi244864, %101
  %103 = fmul contract float %arrayref254, %arrayref254
  %104 = fadd reassoc contract float %value_phi243863, %103
  %105 = add nuw nsw i64 %value_phi245865, 1
  %exitcond1039.not = icmp eq i64 %105, %arraylen240
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
  call void @j__check_residual_1827({}* nonnull %getfield14, i64 signext %arrayref)
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
  store {}* inttoptr (i64 135794572797712 to {}*), {}** %6, align 8
  %122 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %122)
  unreachable

L175:                                             ; preds = %L155.us, %L136, %L134
  %123 = fsub float %value_phi40, %value_phi40
  %124 = fcmp uno float %123, 0.000000e+00
  br i1 %124, label %L490, label %L180

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
  call void @j_throw_boundserror_1822({}* nonnull %getfield72, [1 x i64]* nocapture readonly %newstruct73) #2
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
  %getfield2311799 = load atomic float**, float*** %128 unordered, align 8
  %129 = add i64 %arrayref81, -1
  %arrayptr233638 = load float*, float** %getfield2311799, align 8
  %130 = getelementptr inbounds float, float* %arrayptr233638, i64 %129
  %arrayref234 = load float, float* %130, align 4
  br label %L204

L204:                                             ; preds = %L199, %L194
  %value_phi82 = phi float [ %arrayref234, %L199 ], [ 0.000000e+00, %L194 ]
  br i1 %110, label %L208, label %L206

L206:                                             ; preds = %L204
  %131 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %131, align 8
  %132 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %132, align 16
  %133 = call float @j__coordinate_minimizer_1820({ double }* nocapture nonnull readonly %2, float %value_phi82, i64 signext %arrayref)
  br label %L408

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
  br i1 %143, label %L227, label %L405

L227:                                             ; preds = %L208
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %144 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %144, label %L233, label %L231

L231:                                             ; preds = %L227
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %value_phi40) #2
  unreachable

L233:                                             ; preds = %L227
  %145 = call float @llvm.sqrt.f32(float %value_phi40)
  %146 = fcmp ugt float %145, %aggregate_load_box.sroa.0.0.copyload
  br i1 %146, label %L238, label %L408

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
  %192 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi82, i64 signext %arrayref)
  br label %L408

L293:                                             ; preds = %L282, %L238
  %value_phi204 = phi float [ %150, %L238 ], [ %value_phi202, %L282 ]
  %193 = fcmp uge float %value_phi204, 0.000000e+00
  br i1 %193, label %L298, label %L296

L296:                                             ; preds = %L293
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %value_phi204) #2
  unreachable

L298:                                             ; preds = %L293
  %194 = call float @llvm.sqrt.f32(float %value_phi204)
  %195 = fsub float %145, %aggregate_load_box.sroa.0.0.copyload
  %196 = fcmp uge float %195, 0.000000e+00
  br i1 %196, label %L305, label %L303

L303:                                             ; preds = %L298
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %195) #2
  unreachable

L305:                                             ; preds = %L298
  %197 = fadd float %145, %aggregate_load_box.sroa.0.0.copyload
  %198 = fcmp uge float %197, 0.000000e+00
  br i1 %198, label %L312, label %L310

L310:                                             ; preds = %L305
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %197) #2
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
  br label %L408

L403:                                             ; preds = %L312
  %217 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %217, align 8
  %218 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %218, align 16
  %219 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi82, i64 signext %arrayref)
  br label %L408

L405:                                             ; preds = %L208
  %220 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %220, align 8
  %221 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 4
  store {}* %getfield10, {}** %221, align 16
  %222 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi82, i64 signext %arrayref)
  br label %L408

L408:                                             ; preds = %L405, %L403, %L346, %L291, %L233, %L206
  %value_phi83 = phi float [ %133, %L206 ], [ %192, %L291 ], [ %219, %L403 ], [ %222, %L405 ], [ 0.000000e+00, %L233 ], [ %216, %L346 ]
  %getfield85 = load atomic {}*, {}** %40 unordered, align 8
  %223 = bitcast {}* %getfield85 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr86 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %223, i64 0, i32 1
  %arraylen87 = load i64, i64* %arraylen_ptr86, align 8
  %inbounds88 = icmp ult i64 %41, %arraylen87
  br i1 %inbounds88, label %idxend91, label %oob89

L416:                                             ; preds = %idxend91
  %getfield107 = load atomic {}*, {}** %25 unordered, align 8
  %224 = bitcast {}* %getfield107 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr109 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %224, i64 0, i32 1
  %arraylen110 = load i64, i64* %arraylen_ptr109, align 8
  %.not617 = icmp ult i64 %41, %arraylen110
  br i1 %.not617, label %L430, label %L427

L427:                                             ; preds = %L416
  store i64 %arrayref, i64* %30, align 8
  store {}* %getfield107, {}** %19, align 16
  call void @j_throw_boundserror_1822({}* nonnull %getfield107, [1 x i64]* nocapture readonly %newstruct108) #2
  unreachable

L430:                                             ; preds = %L416
  %225 = bitcast {}* %getfield107 to i64**
  %arrayptr115618 = load i64*, i64** %225, align 8
  %226 = getelementptr inbounds i64, i64* %arrayptr115618, i64 %41
  %arrayref116 = load i64, i64* %226, align 8
  %.not619 = icmp eq i64 %arrayref116, 0
  br i1 %.not619, label %L438, label %L435

L435:                                             ; preds = %L430
  %227 = bitcast {}* %0 to float***
  %getfield1181800 = load atomic float**, float*** %227 unordered, align 8
  %228 = add i64 %arrayref116, -1
  %arrayptr120620 = load float*, float** %getfield1181800, align 8
  %229 = getelementptr inbounds float, float* %arrayptr120620, i64 %228
  store float %value_phi83, float* %229, align 4
  br label %L455

L438:                                             ; preds = %L430
  %230 = fcmp oeq float %value_phi83, 0.000000e+00
  br i1 %230, label %L455, label %L441

L441:                                             ; preds = %L438
  %231 = load i64, i64* %32, align 8
  %232 = add i64 %231, 1
  store i64 %232, i64* %32, align 8
  %getfield143 = load atomic {}*, {}** %27 unordered, align 8
  %233 = bitcast {}* %getfield143 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr144 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %233, i64 0, i32 1
  %arraylen145 = load i64, i64* %arraylen_ptr144, align 8
  %inbounds146 = icmp ult i64 %231, %arraylen145
  br i1 %inbounds146, label %idxend149, label %oob147

L455:                                             ; preds = %idxend169, %L438, %L435
  %getfield122 = load atomic {}*, {}** %39 unordered, align 8
  %234 = bitcast {}* %getfield122 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr125 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %234, i64 0, i32 1
  %arraylen126 = load i64, i64* %arraylen_ptr125, align 8
  %.not621 = icmp eq i64 %arraylen126, 0
  br i1 %.not621, label %L492, label %L468.lr.ph

L468.lr.ph:                                       ; preds = %L455
  %getfield124 = load atomic {}*, {}** %37 unordered, align 8
  %235 = bitcast {}* %getfield122 to float**
  %arrayptr131623 = load float*, float** %235, align 8
  %236 = bitcast {}* %getfield124 to {}**
  %arraysize_ptr133 = getelementptr inbounds {}*, {}** %236, i64 3
  %237 = bitcast {}** %arraysize_ptr133 to i64*
  %arraysize134 = load i64, i64* %237, align 8
  %238 = mul i64 %arraysize134, %41
  %239 = bitcast {}* %getfield124 to float**
  %arrayptr137624 = load float*, float** %239, align 8
  %min.iters.check = icmp ult i64 %arraylen126, 32
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L468.lr.ph
  %scevgep = getelementptr float, float* %arrayptr131623, i64 %arraylen126
  %scevgep1446 = getelementptr float, float* %arrayptr137624, i64 %238
  %240 = add i64 %arraylen126, %238
  %scevgep1448 = getelementptr float, float* %arrayptr137624, i64 %240
  %bound0 = icmp ult float* %arrayptr131623, %scevgep1448
  %bound1 = icmp ult float* %scevgep1446, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen126, 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %551, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %241 = getelementptr inbounds float, float* %arrayptr131623, i64 %index
  %242 = bitcast float* %241 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %242, align 4
  %243 = getelementptr inbounds float, float* %241, i64 8
  %244 = bitcast float* %243 to <8 x float>*
  %wide.load1450 = load <8 x float>, <8 x float>* %244, align 4
  %245 = getelementptr inbounds float, float* %241, i64 16
  %246 = bitcast float* %245 to <8 x float>*
  %wide.load1451 = load <8 x float>, <8 x float>* %246, align 4
  %247 = getelementptr inbounds float, float* %241, i64 24
  %248 = bitcast float* %247 to <8 x float>*
  %wide.load1452 = load <8 x float>, <8 x float>* %248, align 4
  %249 = add i64 %238, %index
  %250 = getelementptr inbounds float, float* %arrayptr137624, i64 %249
  %251 = bitcast float* %250 to <8 x float>*
  %wide.load1453 = load <8 x float>, <8 x float>* %251, align 4
  %252 = getelementptr inbounds float, float* %250, i64 8
  %253 = bitcast float* %252 to <8 x float>*
  %wide.load1454 = load <8 x float>, <8 x float>* %253, align 4
  %254 = getelementptr inbounds float, float* %250, i64 16
  %255 = bitcast float* %254 to <8 x float>*
  %wide.load1455 = load <8 x float>, <8 x float>* %255, align 4
  %256 = getelementptr inbounds float, float* %250, i64 24
  %257 = bitcast float* %256 to <8 x float>*
  %wide.load1456 = load <8 x float>, <8 x float>* %257, align 4
  %258 = fmul <8 x float> %broadcast.splat, %wide.load1453
  %259 = fmul <8 x float> %broadcast.splat, %wide.load1454
  %260 = fmul <8 x float> %broadcast.splat, %wide.load1455
  %261 = fmul <8 x float> %broadcast.splat, %wide.load1456
  %262 = fsub <8 x float> %wide.load, %258
  %263 = fsub <8 x float> %wide.load1450, %259
  %264 = fsub <8 x float> %wide.load1451, %260
  %265 = fsub <8 x float> %wide.load1452, %261
  store <8 x float> %262, <8 x float>* %242, align 4
  store <8 x float> %263, <8 x float>* %244, align 4
  store <8 x float> %264, <8 x float>* %246, align 4
  store <8 x float> %265, <8 x float>* %248, align 4
  %index.next = add nuw i64 %index, 32
  %266 = icmp eq i64 %index.next, %n.vec
  br i1 %266, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen126, %n.vec
  br i1 %cmp.n, label %L492, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L468.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L468.lr.ph ], [ 0, %vector.memcheck ]
  br label %L468

L468:                                             ; preds = %L468, %scalar.ph
  %value_phi129873 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %272, %L468 ]
  %267 = getelementptr inbounds float, float* %arrayptr131623, i64 %value_phi129873
  %arrayref132 = load float, float* %267, align 4
  %268 = add i64 %238, %value_phi129873
  %269 = getelementptr inbounds float, float* %arrayptr137624, i64 %268
  %arrayref138 = load float, float* %269, align 4
  %270 = fmul float %551, %arrayref138
  %271 = fsub float %arrayref132, %270
  store float %271, float* %267, align 4
  %272 = add nuw nsw i64 %value_phi129873, 1
  %exitcond1041.not = icmp eq i64 %272, %arraylen126
  br i1 %exitcond1041.not, label %L492, label %L468

L490:                                             ; preds = %L175
  call void @j__refuse_curvature_1826(i64 signext %arrayref) #2
  unreachable

L492:                                             ; preds = %idxend91, %L468, %middle.block, %L455
  %arrayref936 = phi i64 [ %arrayref, %L455 ], [ %arrayref937, %idxend91 ], [ %arrayref, %middle.block ], [ %arrayref, %L468 ]
  %273 = call float @llvm.fabs.f32(float %551)
  %274 = fcmp oeq float %551, 0.000000e+00
  %or.cond = select i1 %.not614, i1 true, i1 %274
  br i1 %or.cond, label %L503, label %L498

L498:                                             ; preds = %L492
  %getfield96 = load atomic {}*, {}** %23 unordered, align 8
  %275 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %20, {}** %275, align 8
  store {}* %getfield96, {}** %19, align 16
  %276 = call float @j_coordinate_scale_1821({}* nonnull %getfield96, {}* nonnull %0, i64 signext %arrayref)
  %277 = fmul float %273, %276
  br label %L503

L503:                                             ; preds = %L498, %L492
  %value_phi97 = phi float [ %277, %L498 ], [ %273, %L492 ]
  %278 = fsub float %value_phi97, %value_phi97
  %279 = fcmp uno float %278, 0.000000e+00
  br i1 %279, label %L509, label %L512

L509:                                             ; preds = %L503
  store {}* inttoptr (i64 135794568852048 to {}*), {}** %6, align 8
  %280 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %280)
  unreachable

L512:                                             ; preds = %L503
  %.inv615 = fcmp olt float %value_phi7, %value_phi97
  %281 = select i1 %.inv615, float %value_phi97, float %value_phi7
  %.not616.not = icmp eq i64 %value_phi5, %value_phi
  %282 = add nuw i64 %value_phi5, 1
  br i1 %.not616.not, label %L1049.loopexit691, label %L22

L529:                                             ; preds = %top
  %unbox261 = load i64, i64* %14, align 8
  %283 = call i64 @llvm.smax.i64(i64 %unbox261, i64 0)
  %284 = icmp slt i64 %unbox261, 1
  br i1 %284, label %L1049, label %L545.preheader

L545.preheader:                                   ; preds = %L529
  %285 = bitcast {}* %1 to {}**
  %286 = bitcast {}* %0 to i8*
  %getfield_addr346 = getelementptr inbounds i8, i8* %286, i64 16
  %287 = bitcast i8* %getfield_addr346 to {}**
  %288 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct348, i64 0, i64 0
  %289 = bitcast {}* %0 to {}**
  %290 = bitcast {}* %1 to i8*
  %291 = getelementptr inbounds i8, i8* %290, i64 8
  %aggregate_load_box452.sroa.0.0..sroa_idx = bitcast i8* %291 to float*
  %292 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct381, i64 0, i64 0
  %293 = getelementptr inbounds i8, i8* %286, i64 24
  %294 = bitcast i8* %293 to i64*
  %getfield_addr425 = getelementptr inbounds i8, i8* %286, i64 8
  %295 = bitcast i8* %getfield_addr425 to {}**
  %296 = and i8 %4, 1
  %.not657 = icmp eq i8 %296, 0
  br label %L545

L545:                                             ; preds = %L1034, %L545.preheader
  %indvar = phi i64 [ 0, %L545.preheader ], [ %indvar.next, %L1034 ]
  %value_phi266998 = phi i64 [ undef, %L545.preheader ], [ %value_phi266997, %L1034 ]
  %value_phi266 = phi i64 [ 1, %L545.preheader ], [ %541, %L1034 ]
  %value_phi268 = phi float [ 0.000000e+00, %L545.preheader ], [ %540, %L1034 ]
  %297 = shl i64 %indvar, 2
  %getfield271 = load atomic {}*, {}** %285 unordered, align 8
  %298 = bitcast {}* %getfield271 to {}**
  %getfield273 = load atomic {}*, {}** %298 unordered, align 8
  %299 = bitcast {}* %getfield271 to i8*
  %getfield_addr274 = getelementptr inbounds i8, i8* %299, i64 24
  %300 = bitcast i8* %getfield_addr274 to {}**
  %getfield275 = load atomic {}*, {}** %300 unordered, align 8
  %getfield_addr276 = getelementptr inbounds i8, i8* %299, i64 32
  %301 = bitcast i8* %getfield_addr276 to {}**
  %getfield277 = load atomic {}*, {}** %301 unordered, align 8
  %302 = add nsw i64 %value_phi266, -1
  %303 = bitcast {}* %getfield277 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr278 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %303, i64 0, i32 1
  %arraylen279 = load i64, i64* %arraylen_ptr278, align 8
  %inbounds280 = icmp ult i64 %302, %arraylen279
  br i1 %inbounds280, label %idxend283, label %oob281

L565:                                             ; preds = %idxend283
  br i1 %.not683, label %L649, label %L579.lr.ph

L579.lr.ph:                                       ; preds = %L565
  %304 = bitcast {}* %getfield273 to {}**
  %arraysize_ptr295 = getelementptr inbounds {}*, {}** %304, i64 3
  %305 = bitcast {}** %arraysize_ptr295 to i64*
  %arraysize296 = load i64, i64* %305, align 8
  %306 = mul i64 %arraysize296, %302
  %307 = bitcast {}* %getfield273 to float**
  %arrayptr299647 = load float*, float** %307, align 8
  %308 = bitcast {}* %getfield275 to float**
  %arrayptr302648 = load float*, float** %308, align 8
  %min.iters.check1611 = icmp ult i64 %arraylen515, 8
  br i1 %min.iters.check1611, label %scalar.ph1610, label %vector.ph1612

vector.ph1612:                                    ; preds = %L579.lr.ph
  %n.vec1614 = and i64 %arraylen515, 9223372036854775800
  br label %vector.body1617

vector.body1617:                                  ; preds = %vector.body1617, %vector.ph1612
  %index1618 = phi i64 [ 0, %vector.ph1612 ], [ %index.next1624, %vector.body1617 ]
  %vec.phi1619 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %315, %vector.body1617 ]
  %vec.phi1620 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %317, %vector.body1617 ]
  %vec.phi1621 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1612 ], [ %319, %vector.body1617 ]
  %309 = add i64 %306, %index1618
  %310 = getelementptr inbounds float, float* %arrayptr299647, i64 %309
  %311 = bitcast float* %310 to <8 x float>*
  %wide.load1622 = load <8 x float>, <8 x float>* %311, align 4
  %312 = getelementptr inbounds float, float* %arrayptr302648, i64 %index1618
  %313 = bitcast float* %312 to <8 x float>*
  %wide.load1623 = load <8 x float>, <8 x float>* %313, align 4
  %314 = fmul contract <8 x float> %wide.load1622, %wide.load1622
  %315 = fadd reassoc contract <8 x float> %vec.phi1619, %314
  %316 = fmul contract <8 x float> %wide.load1622, %wide.load1623
  %317 = fadd reassoc contract <8 x float> %vec.phi1620, %316
  %318 = fmul contract <8 x float> %wide.load1623, %wide.load1623
  %319 = fadd reassoc contract <8 x float> %vec.phi1621, %318
  %index.next1624 = add nuw i64 %index1618, 8
  %320 = icmp eq i64 %index.next1624, %n.vec1614
  br i1 %320, label %middle.block1609, label %vector.body1617

middle.block1609:                                 ; preds = %vector.body1617
  %321 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %319)
  %322 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %317)
  %323 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %315)
  %cmp.n1616 = icmp eq i64 %arraylen515, %n.vec1614
  br i1 %cmp.n1616, label %L649, label %scalar.ph1610

scalar.ph1610:                                    ; preds = %middle.block1609, %L579.lr.ph
  %bc.resume.val1615 = phi i64 [ %n.vec1614, %middle.block1609 ], [ 0, %L579.lr.ph ]
  %bc.merge.rdx1625 = phi float [ %323, %middle.block1609 ], [ 0.000000e+00, %L579.lr.ph ]
  %bc.merge.rdx1626 = phi float [ %322, %middle.block1609 ], [ 0.000000e+00, %L579.lr.ph ]
  %bc.merge.rdx1627 = phi float [ %321, %middle.block1609 ], [ 0.000000e+00, %L579.lr.ph ]
  br label %L579

L579:                                             ; preds = %L579, %scalar.ph1610
  %value_phi294878 = phi float [ %bc.merge.rdx1625, %scalar.ph1610 ], [ %328, %L579 ]
  %value_phi293877 = phi i64 [ %bc.resume.val1615, %scalar.ph1610 ], [ %333, %L579 ]
  %value_phi292876 = phi float [ %bc.merge.rdx1626, %scalar.ph1610 ], [ %330, %L579 ]
  %value_phi291875 = phi float [ %bc.merge.rdx1627, %scalar.ph1610 ], [ %332, %L579 ]
  %324 = add i64 %306, %value_phi293877
  %325 = getelementptr inbounds float, float* %arrayptr299647, i64 %324
  %arrayref300 = load float, float* %325, align 4
  %326 = getelementptr inbounds float, float* %arrayptr302648, i64 %value_phi293877
  %arrayref303 = load float, float* %326, align 4
  %327 = fmul contract float %arrayref300, %arrayref300
  %328 = fadd reassoc contract float %value_phi294878, %327
  %329 = fmul contract float %arrayref300, %arrayref303
  %330 = fadd reassoc contract float %value_phi292876, %329
  %331 = fmul contract float %arrayref303, %arrayref303
  %332 = fadd reassoc contract float %value_phi291875, %331
  %333 = add nuw nsw i64 %value_phi293877, 1
  %exitcond1042.not = icmp eq i64 %333, %arraylen515
  br i1 %exitcond1042.not, label %L649, label %L579

L608:                                             ; preds = %idxend283
  br i1 %.not683, label %L649, label %L621.lr.ph

L621.lr.ph:                                       ; preds = %L608
  %334 = bitcast {}* %getfield273 to {}**
  %arraysize_ptr521 = getelementptr inbounds {}*, {}** %334, i64 3
  %335 = bitcast {}** %arraysize_ptr521 to i64*
  %arraysize522 = load i64, i64* %335, align 8
  %336 = mul i64 %arraysize522, %302
  %337 = bitcast {}* %getfield273 to float**
  %arrayptr525685 = load float*, float** %337, align 8
  %338 = bitcast {}* %getfield275 to float**
  %arrayptr528686 = load float*, float** %338, align 8
  %min.iters.check1588 = icmp ult i64 %arraylen515, 16
  br i1 %min.iters.check1588, label %scalar.ph1587, label %vector.ph1589

vector.ph1589:                                    ; preds = %L621.lr.ph
  %n.vec1591 = and i64 %arraylen515, 9223372036854775792
  br label %vector.body1594

vector.body1594:                                  ; preds = %vector.body1594, %vector.ph1589
  %index1595 = phi i64 [ 0, %vector.ph1589 ], [ %index.next1604, %vector.body1594 ]
  %vec.phi1596 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %350, %vector.body1594 ]
  %vec.phi1597 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %351, %vector.body1594 ]
  %vec.phi1598 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %354, %vector.body1594 ]
  %vec.phi1599 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1589 ], [ %355, %vector.body1594 ]
  %339 = add i64 %336, %index1595
  %340 = getelementptr inbounds float, float* %arrayptr525685, i64 %339
  %341 = bitcast float* %340 to <8 x float>*
  %wide.load1600 = load <8 x float>, <8 x float>* %341, align 4
  %342 = getelementptr inbounds float, float* %340, i64 8
  %343 = bitcast float* %342 to <8 x float>*
  %wide.load1601 = load <8 x float>, <8 x float>* %343, align 4
  %344 = getelementptr inbounds float, float* %arrayptr528686, i64 %index1595
  %345 = bitcast float* %344 to <8 x float>*
  %wide.load1602 = load <8 x float>, <8 x float>* %345, align 4
  %346 = getelementptr inbounds float, float* %344, i64 8
  %347 = bitcast float* %346 to <8 x float>*
  %wide.load1603 = load <8 x float>, <8 x float>* %347, align 4
  %348 = fmul contract <8 x float> %wide.load1600, %wide.load1602
  %349 = fmul contract <8 x float> %wide.load1601, %wide.load1603
  %350 = fadd reassoc contract <8 x float> %vec.phi1596, %348
  %351 = fadd reassoc contract <8 x float> %vec.phi1597, %349
  %352 = fmul contract <8 x float> %wide.load1602, %wide.load1602
  %353 = fmul contract <8 x float> %wide.load1603, %wide.load1603
  %354 = fadd reassoc contract <8 x float> %vec.phi1598, %352
  %355 = fadd reassoc contract <8 x float> %vec.phi1599, %353
  %index.next1604 = add nuw i64 %index1595, 16
  %356 = icmp eq i64 %index.next1604, %n.vec1591
  br i1 %356, label %middle.block1586, label %vector.body1594

middle.block1586:                                 ; preds = %vector.body1594
  %bin.rdx1607 = fadd reassoc contract <8 x float> %355, %354
  %357 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1607)
  %bin.rdx1605 = fadd reassoc contract <8 x float> %351, %350
  %358 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1605)
  %cmp.n1593 = icmp eq i64 %arraylen515, %n.vec1591
  br i1 %cmp.n1593, label %L649, label %scalar.ph1587

scalar.ph1587:                                    ; preds = %middle.block1586, %L621.lr.ph
  %bc.resume.val1592 = phi i64 [ %n.vec1591, %middle.block1586 ], [ 0, %L621.lr.ph ]
  %bc.merge.rdx1606 = phi float [ %358, %middle.block1586 ], [ 0.000000e+00, %L621.lr.ph ]
  %bc.merge.rdx1608 = phi float [ %357, %middle.block1586 ], [ 0.000000e+00, %L621.lr.ph ]
  br label %L621

L621:                                             ; preds = %L621, %scalar.ph1587
  %value_phi520885 = phi i64 [ %bc.resume.val1592, %scalar.ph1587 ], [ %366, %L621 ]
  %value_phi519884 = phi float [ %bc.merge.rdx1606, %scalar.ph1587 ], [ %363, %L621 ]
  %value_phi518883 = phi float [ %bc.merge.rdx1608, %scalar.ph1587 ], [ %365, %L621 ]
  %359 = add i64 %336, %value_phi520885
  %360 = getelementptr inbounds float, float* %arrayptr525685, i64 %359
  %arrayref526 = load float, float* %360, align 4
  %361 = getelementptr inbounds float, float* %arrayptr528686, i64 %value_phi520885
  %arrayref529 = load float, float* %361, align 4
  %362 = fmul contract float %arrayref526, %arrayref529
  %363 = fadd reassoc contract float %value_phi519884, %362
  %364 = fmul contract float %arrayref529, %arrayref529
  %365 = fadd reassoc contract float %value_phi518883, %364
  %366 = add nuw nsw i64 %value_phi520885, 1
  %exitcond1043.not = icmp eq i64 %366, %arraylen515
  br i1 %exitcond1043.not, label %L649, label %L621

L649:                                             ; preds = %L621, %middle.block1586, %L608, %L579, %middle.block1609, %L565
  %value_phi311 = phi float [ 0.000000e+00, %L565 ], [ 0.000000e+00, %L608 ], [ %357, %middle.block1586 ], [ %321, %middle.block1609 ], [ %365, %L621 ], [ %332, %L579 ]
  %value_phi312 = phi float [ 0.000000e+00, %L565 ], [ 0.000000e+00, %L608 ], [ %358, %middle.block1586 ], [ %322, %middle.block1609 ], [ %363, %L621 ], [ %330, %L579 ]
  %value_phi313 = phi float [ 0.000000e+00, %L565 ], [ %arrayref286, %L608 ], [ %arrayref286, %middle.block1586 ], [ %323, %middle.block1609 ], [ %arrayref286, %L621 ], [ %328, %L579 ]
  %367 = fsub float %value_phi311, %value_phi311
  %368 = fcmp uno float %367, 0.000000e+00
  br i1 %368, label %L654, label %L656

L654:                                             ; preds = %L649
  %369 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield271, {}** %369, align 8
  %370 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield275, {}** %370, align 16
  call void @j__check_residual_1827({}* nonnull %getfield275, i64 signext %value_phi266)
  br label %L656

L656:                                             ; preds = %L654, %L649
  %371 = fcmp une float %value_phi313, 0.000000e+00
  br i1 %371, label %L697, label %L658

L658:                                             ; preds = %L656
  %getfield315 = load atomic {}*, {}** %298 unordered, align 8
  %372 = bitcast {}* %getfield315 to {}**
  %arraysize_ptr316 = getelementptr inbounds {}*, {}** %372, i64 3
  %373 = bitcast {}** %arraysize_ptr316 to i64*
  %arraysize317 = load i64, i64* %373, align 8
  %.not649.not = icmp eq i64 %arraysize317, 0
  br i1 %.not649.not, label %L697, label %L671.preheader

L671.preheader:                                   ; preds = %L658
  %arraysize_ptr331 = getelementptr inbounds {}*, {}** %372, i64 4
  %374 = bitcast {}** %arraysize_ptr331 to i64*
  %arraysize332 = load i64, i64* %374, align 8
  %inbounds333 = icmp ult i64 %302, %arraysize332
  %375 = mul i64 %arraysize317, %302
  %376 = bitcast {}* %getfield315 to float**
  %arrayptr338651 = load float*, float** %376, align 8
  %inbounds333.fr = freeze i1 %inbounds333
  br i1 %inbounds333.fr, label %ib329.us, label %oob334

ib329.us:                                         ; preds = %L677.us, %L671.preheader
  %value_phi322.us = phi i64 [ %381, %L677.us ], [ 1, %L671.preheader ]
  %377 = add nsw i64 %value_phi322.us, -1
  %378 = add i64 %375, %377
  %379 = getelementptr inbounds float, float* %arrayptr338651, i64 %378
  %arrayref339.us = load float, float* %379, align 4
  %380 = fcmp une float %arrayref339.us, 0.000000e+00
  br i1 %380, label %L693.split.us, label %L677.us

L677.us:                                          ; preds = %ib329.us
  %381 = add nuw nsw i64 %value_phi322.us, 1
  %382 = icmp ult i64 %value_phi322.us, %arraysize317
  br i1 %382, label %ib329.us, label %L697

L693.split.us:                                    ; preds = %ib329.us
  store {}* inttoptr (i64 135794572797712 to {}*), {}** %6, align 8
  %383 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %383)
  unreachable

L697:                                             ; preds = %L677.us, %L658, %L656
  %384 = fsub float %value_phi313, %value_phi313
  %385 = fcmp uno float %384, 0.000000e+00
  br i1 %385, label %L1012, label %L702

L702:                                             ; preds = %L697
  %getfield347 = load atomic {}*, {}** %287 unordered, align 8
  %386 = bitcast {}* %getfield347 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr349 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %386, i64 0, i32 1
  %arraylen350 = load i64, i64* %arraylen_ptr349, align 8
  %.not653 = icmp ult i64 %302, %arraylen350
  br i1 %.not653, label %L716, label %L713

L713:                                             ; preds = %L702
  store i64 %value_phi266, i64* %288, align 8
  %387 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield347, {}** %387, align 16
  call void @j_throw_boundserror_1822({}* nonnull %getfield347, [1 x i64]* nocapture readonly %newstruct348) #2
  unreachable

L716:                                             ; preds = %L702
  %388 = bitcast {}* %getfield347 to i64**
  %arrayptr355654 = load i64*, i64** %388, align 8
  %389 = getelementptr inbounds i64, i64* %arrayptr355654, i64 %302
  %arrayref356 = load i64, i64* %389, align 8
  %.not655 = icmp eq i64 %arrayref356, 0
  br i1 %.not655, label %L726, label %L721

L721:                                             ; preds = %L716
  %390 = bitcast {}* %0 to float***
  %getfield5061801 = load atomic float**, float*** %390 unordered, align 8
  %391 = add i64 %arrayref356, -1
  %arrayptr508682 = load float*, float** %getfield5061801, align 8
  %392 = getelementptr inbounds float, float* %arrayptr508682, i64 %391
  %arrayref509 = load float, float* %392, align 4
  br label %L726

L726:                                             ; preds = %L721, %L716
  %value_phi357 = phi float [ %arrayref509, %L721 ], [ 0.000000e+00, %L716 ]
  br i1 %371, label %L730, label %L728

L728:                                             ; preds = %L726
  %393 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield271, {}** %393, align 8
  %394 = call float @j__coordinate_minimizer_1820({ double }* nocapture nonnull readonly %2, float %value_phi357, i64 signext %value_phi266)
  br label %L930

L730:                                             ; preds = %L726
  %getfield447 = load atomic {}*, {}** %285 unordered, align 8
  %395 = bitcast {}* %getfield447 to i8*
  %getfield_addr448 = getelementptr inbounds i8, i8* %395, i64 24
  %396 = bitcast i8* %getfield_addr448 to {}**
  %getfield449 = load atomic {}*, {}** %396 unordered, align 8
  %397 = bitcast {}* %getfield449 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr450 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %397, i64 0, i32 1
  %arraylen451 = load i64, i64* %arraylen_ptr450, align 8
  %398 = sitofp i64 %arraylen451 to float
  %399 = fmul float %398, 0x3980000000000000
  %400 = fcmp ole float %399, %value_phi313
  %401 = fcmp ord float %367, 0.000000e+00
  %402 = fcmp ole float %399, %value_phi311
  %403 = and i1 %401, %402
  %404 = and i1 %400, %403
  br i1 %404, label %L749, label %L927

L749:                                             ; preds = %L730
  %aggregate_load_box452.sroa.0.0.copyload = load float, float* %aggregate_load_box452.sroa.0.0..sroa_idx, align 1
  %405 = fcmp uge float %value_phi313, 0.000000e+00
  br i1 %405, label %L755, label %L753

L753:                                             ; preds = %L749
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %value_phi313) #2
  unreachable

L755:                                             ; preds = %L749
  %406 = call float @llvm.sqrt.f32(float %value_phi313)
  %407 = fcmp ugt float %406, %aggregate_load_box452.sroa.0.0.copyload
  br i1 %407, label %L760, label %L930

L760:                                             ; preds = %L755
  %408 = fdiv float %value_phi312, %value_phi313
  %409 = fadd float %408, %value_phi357
  %410 = fmul float %value_phi312, %408
  %411 = fsub float %value_phi311, %410
  %412 = fmul float %value_phi311, 6.250000e-02
  %413 = fcmp uge float %411, %412
  br i1 %413, label %L815, label %L767

L767:                                             ; preds = %L760
  %.not672 = icmp eq i64 %arraylen451, 0
  br i1 %.not672, label %L804, label %L781.lr.ph

L781.lr.ph:                                       ; preds = %L767
  %414 = bitcast {}* %getfield447 to {}**
  %getfield457 = load atomic {}*, {}** %414 unordered, align 8
  %415 = bitcast {}* %getfield449 to float**
  %arrayptr467674 = load float*, float** %415, align 8
  %416 = bitcast {}* %getfield457 to {}**
  %arraysize_ptr469 = getelementptr inbounds {}*, {}** %416, i64 3
  %417 = bitcast {}** %arraysize_ptr469 to i64*
  %arraysize470 = load i64, i64* %417, align 8
  %418 = mul i64 %arraysize470, %302
  %419 = bitcast {}* %getfield457 to float**
  %arrayptr473675 = load float*, float** %419, align 8
  %min.iters.check1565 = icmp ult i64 %arraylen451, 16
  br i1 %min.iters.check1565, label %scalar.ph1564, label %vector.ph1566

vector.ph1566:                                    ; preds = %L781.lr.ph
  %n.vec1568 = and i64 %arraylen451, 9223372036854775792
  %broadcast.splatinsert1579 = insertelement <8 x float> poison, float %408, i64 0
  %broadcast.splat1580 = shufflevector <8 x float> %broadcast.splatinsert1579, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1571

vector.body1571:                                  ; preds = %vector.body1571, %vector.ph1566
  %index1572 = phi i64 [ 0, %vector.ph1566 ], [ %index.next1583, %vector.body1571 ]
  %vec.phi1573 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1566 ], [ %435, %vector.body1571 ]
  %vec.phi1574 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1566 ], [ %436, %vector.body1571 ]
  %420 = getelementptr inbounds float, float* %arrayptr467674, i64 %index1572
  %421 = bitcast float* %420 to <8 x float>*
  %wide.load1575 = load <8 x float>, <8 x float>* %421, align 4
  %422 = getelementptr inbounds float, float* %420, i64 8
  %423 = bitcast float* %422 to <8 x float>*
  %wide.load1576 = load <8 x float>, <8 x float>* %423, align 4
  %424 = add i64 %418, %index1572
  %425 = getelementptr inbounds float, float* %arrayptr473675, i64 %424
  %426 = bitcast float* %425 to <8 x float>*
  %wide.load1577 = load <8 x float>, <8 x float>* %426, align 4
  %427 = getelementptr inbounds float, float* %425, i64 8
  %428 = bitcast float* %427 to <8 x float>*
  %wide.load1578 = load <8 x float>, <8 x float>* %428, align 4
  %429 = fmul <8 x float> %broadcast.splat1580, %wide.load1577
  %430 = fmul <8 x float> %broadcast.splat1580, %wide.load1578
  %431 = fsub <8 x float> %wide.load1575, %429
  %432 = fsub <8 x float> %wide.load1576, %430
  %433 = fmul contract <8 x float> %431, %431
  %434 = fmul contract <8 x float> %432, %432
  %435 = fadd reassoc contract <8 x float> %vec.phi1573, %433
  %436 = fadd reassoc contract <8 x float> %vec.phi1574, %434
  %index.next1583 = add nuw i64 %index1572, 16
  %437 = icmp eq i64 %index.next1583, %n.vec1568
  br i1 %437, label %middle.block1563, label %vector.body1571

middle.block1563:                                 ; preds = %vector.body1571
  %bin.rdx1584 = fadd reassoc contract <8 x float> %436, %435
  %438 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1584)
  %cmp.n1570 = icmp eq i64 %arraylen451, %n.vec1568
  br i1 %cmp.n1570, label %L804, label %scalar.ph1564

scalar.ph1564:                                    ; preds = %middle.block1563, %L781.lr.ph
  %bc.resume.val1569 = phi i64 [ %n.vec1568, %middle.block1563 ], [ 0, %L781.lr.ph ]
  %bc.merge.rdx1585 = phi float [ %438, %middle.block1563 ], [ 0.000000e+00, %L781.lr.ph ]
  br label %L781

L781:                                             ; preds = %L781, %scalar.ph1564
  %value_phi465890 = phi i64 [ %bc.resume.val1569, %scalar.ph1564 ], [ %446, %L781 ]
  %value_phi464889 = phi float [ %bc.merge.rdx1585, %scalar.ph1564 ], [ %445, %L781 ]
  %439 = getelementptr inbounds float, float* %arrayptr467674, i64 %value_phi465890
  %arrayref468 = load float, float* %439, align 4
  %440 = add i64 %418, %value_phi465890
  %441 = getelementptr inbounds float, float* %arrayptr473675, i64 %440
  %arrayref474 = load float, float* %441, align 4
  %442 = fmul float %408, %arrayref474
  %443 = fsub float %arrayref468, %442
  %444 = fmul contract float %443, %443
  %445 = fadd reassoc contract float %value_phi464889, %444
  %446 = add nuw nsw i64 %value_phi465890, 1
  %exitcond1044.not = icmp eq i64 %446, %arraylen451
  br i1 %exitcond1044.not, label %L804, label %L781

L804:                                             ; preds = %L781, %middle.block1563, %L767
  %value_phi476 = phi float [ 0.000000e+00, %L767 ], [ %438, %middle.block1563 ], [ %445, %L781 ]
  %447 = fsub float %value_phi476, %value_phi476
  %448 = fcmp uno float %447, 0.000000e+00
  %449 = fcmp ugt float %399, %value_phi476
  %450 = or i1 %449, %448
  br i1 %450, label %L813, label %L815

L813:                                             ; preds = %L804
  %451 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield271, {}** %451, align 8
  %452 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi357, i64 signext %value_phi266)
  br label %L930

L815:                                             ; preds = %L804, %L760
  %value_phi478 = phi float [ %411, %L760 ], [ %value_phi476, %L804 ]
  %453 = fcmp uge float %value_phi478, 0.000000e+00
  br i1 %453, label %L820, label %L818

L818:                                             ; preds = %L815
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %value_phi478) #2
  unreachable

L820:                                             ; preds = %L815
  %454 = call float @llvm.sqrt.f32(float %value_phi478)
  %455 = fsub float %406, %aggregate_load_box452.sroa.0.0.copyload
  %456 = fcmp uge float %455, 0.000000e+00
  br i1 %456, label %L827, label %L825

L825:                                             ; preds = %L820
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %455) #2
  unreachable

L827:                                             ; preds = %L820
  %457 = fadd float %406, %aggregate_load_box452.sroa.0.0.copyload
  %458 = fcmp uge float %457, 0.000000e+00
  br i1 %458, label %L834, label %L832

L832:                                             ; preds = %L827
  call void @j_throw_complex_domainerror_1823({}* inttoptr (i64 135794596555280 to {}*), float %457) #2
  unreachable

L834:                                             ; preds = %L827
  %459 = call float @llvm.sqrt.f32(float %455)
  %460 = call float @llvm.sqrt.f32(float %457)
  %461 = fmul float %459, %460
  %462 = fmul float %406, %461
  %463 = fdiv float %454, %462
  %464 = fmul float %aggregate_load_box452.sroa.0.0.copyload, %463
  %465 = fcmp oge float %462, 0x3810000000000000
  %466 = fcmp oge float %463, 0x3810000000000000
  %467 = fcmp ole float %463, 0x47EFFFFFE0000000
  %narrow676 = and i1 %466, %467
  %468 = and i1 %465, %narrow676
  %469 = fcmp oge float %464, 0x3810000000000000
  %470 = fcmp ole float %464, 0x47EFFFFFE0000000
  %narrow677 = and i1 %469, %470
  %471 = and i1 %468, %narrow677
  br i1 %471, label %L868, label %L925

L868:                                             ; preds = %L834
  %472 = fneg float %464
  %.inv679 = fcmp ogt float %409, %472
  %473 = select i1 %.inv679, float %409, float %472
  %.inv680 = fcmp olt float %473, %464
  %474 = select i1 %.inv680, float %473, float %464
  %475 = fsub float %409, %474
  %476 = fadd float %475, 0.000000e+00
  br label %L930

L925:                                             ; preds = %L834
  %477 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield271, {}** %477, align 8
  %478 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi357, i64 signext %value_phi266)
  br label %L930

L927:                                             ; preds = %L730
  %479 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 3
  store {}* %getfield271, {}** %479, align 8
  %480 = call float @j__sqrt_offrange_step_1825({}* nonnull %1, float %value_phi357, i64 signext %value_phi266)
  br label %L930

L930:                                             ; preds = %L927, %L925, %L868, %L813, %L755, %L728
  %value_phi358 = phi float [ %394, %L728 ], [ %452, %L813 ], [ %478, %L925 ], [ %480, %L927 ], [ 0.000000e+00, %L755 ], [ %476, %L868 ]
  %getfield360 = load atomic {}*, {}** %301 unordered, align 8
  %481 = bitcast {}* %getfield360 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr361 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %481, i64 0, i32 1
  %arraylen362 = load i64, i64* %arraylen_ptr361, align 8
  %inbounds363 = icmp ult i64 %302, %arraylen362
  br i1 %inbounds363, label %idxend366, label %oob364

L938:                                             ; preds = %idxend366
  %getfield380 = load atomic {}*, {}** %287 unordered, align 8
  %482 = bitcast {}* %getfield380 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr382 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %482, i64 0, i32 1
  %arraylen383 = load i64, i64* %arraylen_ptr382, align 8
  %.not660 = icmp ult i64 %302, %arraylen383
  br i1 %.not660, label %L952, label %L949

L949:                                             ; preds = %L938
  store i64 %value_phi266, i64* %292, align 8
  %483 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield380, {}** %483, align 16
  call void @j_throw_boundserror_1822({}* nonnull %getfield380, [1 x i64]* nocapture readonly %newstruct381) #2
  unreachable

L952:                                             ; preds = %L938
  %484 = bitcast {}* %getfield380 to i64**
  %arrayptr388661 = load i64*, i64** %484, align 8
  %485 = getelementptr inbounds i64, i64* %arrayptr388661, i64 %302
  %arrayref389 = load i64, i64* %485, align 8
  %.not662 = icmp eq i64 %arrayref389, 0
  br i1 %.not662, label %L960, label %L957

L957:                                             ; preds = %L952
  %486 = bitcast {}* %0 to float***
  %getfield3911802 = load atomic float**, float*** %486 unordered, align 8
  %487 = add i64 %arrayref389, -1
  %arrayptr393663 = load float*, float** %getfield3911802, align 8
  %488 = getelementptr inbounds float, float* %arrayptr393663, i64 %487
  store float %value_phi358, float* %488, align 4
  br label %L977

L960:                                             ; preds = %L952
  %489 = fcmp oeq float %value_phi358, 0.000000e+00
  br i1 %489, label %L977, label %L963

L963:                                             ; preds = %L960
  %490 = load i64, i64* %294, align 8
  %491 = add i64 %490, 1
  store i64 %491, i64* %294, align 8
  %getfield416 = load atomic {}*, {}** %289 unordered, align 8
  %492 = bitcast {}* %getfield416 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr417 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %492, i64 0, i32 1
  %arraylen418 = load i64, i64* %arraylen_ptr417, align 8
  %inbounds419 = icmp ult i64 %490, %arraylen418
  br i1 %inbounds419, label %idxend422, label %oob420

L977:                                             ; preds = %idxend442, %L960, %L957
  %getfield395 = load atomic {}*, {}** %300 unordered, align 8
  %493 = bitcast {}* %getfield395 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr398 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %493, i64 0, i32 1
  %arraylen399 = load i64, i64* %arraylen_ptr398, align 8
  %.not664 = icmp eq i64 %arraylen399, 0
  br i1 %.not664, label %L1014, label %L990.lr.ph

L990.lr.ph:                                       ; preds = %L977
  %getfield397 = load atomic {}*, {}** %298 unordered, align 8
  %494 = bitcast {}* %getfield395 to float**
  %arrayptr404666 = load float*, float** %494, align 8
  %495 = bitcast {}* %getfield397 to {}**
  %arraysize_ptr406 = getelementptr inbounds {}*, {}** %495, i64 3
  %496 = bitcast {}** %arraysize_ptr406 to i64*
  %arraysize407 = load i64, i64* %496, align 8
  %497 = mul i64 %arraysize407, %302
  %498 = bitcast {}* %getfield397 to float**
  %arrayptr410667 = load float*, float** %498, align 8
  %min.iters.check1538 = icmp ult i64 %arraylen399, 32
  br i1 %min.iters.check1538, label %scalar.ph1537, label %vector.memcheck1525

vector.memcheck1525:                              ; preds = %L990.lr.ph
  %arrayptr4106671529 = bitcast float* %arrayptr410667 to i8*
  %arrayptr4046661526 = bitcast float* %arrayptr404666 to i8*
  %scevgep1527 = getelementptr float, float* %arrayptr404666, i64 %arraylen399
  %scevgep15271528 = bitcast float* %scevgep1527 to i8*
  %499 = mul i64 %arraysize407, %297
  %uglygep = getelementptr i8, i8* %arrayptr4106671529, i64 %499
  %scevgep1530 = getelementptr float, float* %arrayptr410667, i64 %arraylen399
  %scevgep15301531 = bitcast float* %scevgep1530 to i8*
  %uglygep1532 = getelementptr i8, i8* %scevgep15301531, i64 %499
  %bound01533 = icmp ugt i8* %uglygep1532, %arrayptr4046661526
  %bound11534 = icmp ult i8* %uglygep, %scevgep15271528
  %found.conflict1535 = and i1 %bound01533, %bound11534
  br i1 %found.conflict1535, label %scalar.ph1537, label %vector.ph1539

vector.ph1539:                                    ; preds = %vector.memcheck1525
  %n.vec1541 = and i64 %arraylen399, 9223372036854775776
  %broadcast.splatinsert1554 = insertelement <8 x float> poison, float %565, i64 0
  %broadcast.splat1555 = shufflevector <8 x float> %broadcast.splatinsert1554, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1544

vector.body1544:                                  ; preds = %vector.body1544, %vector.ph1539
  %index1545 = phi i64 [ 0, %vector.ph1539 ], [ %index.next1562, %vector.body1544 ]
  %500 = getelementptr inbounds float, float* %arrayptr404666, i64 %index1545
  %501 = bitcast float* %500 to <8 x float>*
  %wide.load1546 = load <8 x float>, <8 x float>* %501, align 4
  %502 = getelementptr inbounds float, float* %500, i64 8
  %503 = bitcast float* %502 to <8 x float>*
  %wide.load1547 = load <8 x float>, <8 x float>* %503, align 4
  %504 = getelementptr inbounds float, float* %500, i64 16
  %505 = bitcast float* %504 to <8 x float>*
  %wide.load1548 = load <8 x float>, <8 x float>* %505, align 4
  %506 = getelementptr inbounds float, float* %500, i64 24
  %507 = bitcast float* %506 to <8 x float>*
  %wide.load1549 = load <8 x float>, <8 x float>* %507, align 4
  %508 = add i64 %497, %index1545
  %509 = getelementptr inbounds float, float* %arrayptr410667, i64 %508
  %510 = bitcast float* %509 to <8 x float>*
  %wide.load1550 = load <8 x float>, <8 x float>* %510, align 4
  %511 = getelementptr inbounds float, float* %509, i64 8
  %512 = bitcast float* %511 to <8 x float>*
  %wide.load1551 = load <8 x float>, <8 x float>* %512, align 4
  %513 = getelementptr inbounds float, float* %509, i64 16
  %514 = bitcast float* %513 to <8 x float>*
  %wide.load1552 = load <8 x float>, <8 x float>* %514, align 4
  %515 = getelementptr inbounds float, float* %509, i64 24
  %516 = bitcast float* %515 to <8 x float>*
  %wide.load1553 = load <8 x float>, <8 x float>* %516, align 4
  %517 = fmul <8 x float> %broadcast.splat1555, %wide.load1550
  %518 = fmul <8 x float> %broadcast.splat1555, %wide.load1551
  %519 = fmul <8 x float> %broadcast.splat1555, %wide.load1552
  %520 = fmul <8 x float> %broadcast.splat1555, %wide.load1553
  %521 = fsub <8 x float> %wide.load1546, %517
  %522 = fsub <8 x float> %wide.load1547, %518
  %523 = fsub <8 x float> %wide.load1548, %519
  %524 = fsub <8 x float> %wide.load1549, %520
  store <8 x float> %521, <8 x float>* %501, align 4
  store <8 x float> %522, <8 x float>* %503, align 4
  store <8 x float> %523, <8 x float>* %505, align 4
  store <8 x float> %524, <8 x float>* %507, align 4
  %index.next1562 = add nuw i64 %index1545, 32
  %525 = icmp eq i64 %index.next1562, %n.vec1541
  br i1 %525, label %middle.block1536, label %vector.body1544

middle.block1536:                                 ; preds = %vector.body1544
  %cmp.n1543 = icmp eq i64 %arraylen399, %n.vec1541
  br i1 %cmp.n1543, label %L1014, label %scalar.ph1537

scalar.ph1537:                                    ; preds = %middle.block1536, %vector.memcheck1525, %L990.lr.ph
  %bc.resume.val1542 = phi i64 [ %n.vec1541, %middle.block1536 ], [ 0, %L990.lr.ph ], [ 0, %vector.memcheck1525 ]
  br label %L990

L990:                                             ; preds = %L990, %scalar.ph1537
  %value_phi402893 = phi i64 [ %bc.resume.val1542, %scalar.ph1537 ], [ %531, %L990 ]
  %526 = getelementptr inbounds float, float* %arrayptr404666, i64 %value_phi402893
  %arrayref405 = load float, float* %526, align 4
  %527 = add i64 %497, %value_phi402893
  %528 = getelementptr inbounds float, float* %arrayptr410667, i64 %527
  %arrayref411 = load float, float* %528, align 4
  %529 = fmul float %565, %arrayref411
  %530 = fsub float %arrayref405, %529
  store float %530, float* %526, align 4
  %531 = add nuw nsw i64 %value_phi402893, 1
  %exitcond1045.not = icmp eq i64 %531, %arraylen399
  br i1 %exitcond1045.not, label %L1014, label %L990

L1012:                                            ; preds = %L697
  call void @j__refuse_curvature_1826(i64 signext %value_phi266) #2
  unreachable

L1014:                                            ; preds = %idxend366, %L990, %middle.block1536, %L977
  %value_phi266997 = phi i64 [ %value_phi266, %L977 ], [ %value_phi266998, %idxend366 ], [ %value_phi266, %middle.block1536 ], [ %value_phi266, %L990 ]
  %532 = call float @llvm.fabs.f32(float %565)
  %533 = fcmp oeq float %565, 0.000000e+00
  %or.cond1292 = select i1 %.not657, i1 true, i1 %533
  br i1 %or.cond1292, label %L1025, label %L1020

L1020:                                            ; preds = %L1014
  %getfield371 = load atomic {}*, {}** %285 unordered, align 8
  %534 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1798, i64 0, i64 2
  store {}* %getfield371, {}** %534, align 16
  %535 = call float @j_coordinate_scale_1821({}* nonnull %getfield371, {}* nonnull %0, i64 signext %value_phi266)
  %536 = fmul float %532, %535
  br label %L1025

L1025:                                            ; preds = %L1020, %L1014
  %value_phi372 = phi float [ %536, %L1020 ], [ %532, %L1014 ]
  %537 = fsub float %value_phi372, %value_phi372
  %538 = fcmp uno float %537, 0.000000e+00
  br i1 %538, label %L1031, label %L1034

L1031:                                            ; preds = %L1025
  store {}* inttoptr (i64 135794568852048 to {}*), {}** %6, align 8
  %539 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %539)
  unreachable

L1034:                                            ; preds = %L1025
  %.inv658 = fcmp olt float %value_phi268, %value_phi372
  %540 = select i1 %.inv658, float %value_phi372, float %value_phi268
  %.not659.not = icmp eq i64 %value_phi266, %283
  %541 = add nuw i64 %value_phi266, 1
  %indvar.next = add i64 %indvar, 1
  br i1 %.not659.not, label %L1049.loopexit, label %L545

L1049.loopexit:                                   ; preds = %L1034
  store i64 %283, i64* %288, align 8
  store i64 %value_phi266997, i64* %292, align 8
  br label %L1049

L1049.loopexit691:                                ; preds = %L512
  store i64 %arrayref, i64* %26, align 8
  store i64 %arrayref936, i64* %30, align 8
  br label %L1049

L1049:                                            ; preds = %L1049.loopexit691, %L1049.loopexit, %L529, %L4
  %value_phi103 = phi float [ 0.000000e+00, %L4 ], [ 0.000000e+00, %L529 ], [ %540, %L1049.loopexit ], [ %281, %L1049.loopexit691 ]
  %542 = load {}*, {}** %10, align 8
  %543 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %542, {}** %543, align 8
  ret float %value_phi103

oob:                                              ; preds = %L22
  %errorbox = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L22
  %544 = bitcast {}* %getfield16 to float**
  %arrayptr18601 = load float*, float** %544, align 8
  %545 = getelementptr inbounds float, float* %arrayptr18601, i64 %41
  %arrayref19 = load float, float* %545, align 4
  %546 = fcmp ord float %arrayref19, 0.000000e+00
  %547 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr239 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %547, i64 0, i32 1
  %arraylen240 = load i64, i64* %arraylen_ptr239, align 8
  %.not639 = icmp eq i64 %arraylen240, 0
  br i1 %546, label %L86, label %L43

oob60:                                            ; preds = %L149.preheader
  %errorbox61607 = alloca [2 x i64], align 8
  %errorbox61607.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 0
  store i64 1, i64* %errorbox61607.sub, align 8
  %548 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 1
  store i64 %arrayref, i64* %548, align 8
  call void @ijl_bounds_error_ints({}* %getfield42, i64* nonnull %errorbox61607.sub, i64 2)
  unreachable

oob89:                                            ; preds = %L408
  %errorbox90 = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox90, align 8
  call void @ijl_bounds_error_ints({}* %getfield85, i64* nonnull %errorbox90, i64 1)
  unreachable

idxend91:                                         ; preds = %L408
  %549 = bitcast {}* %getfield85 to float**
  %arrayptr93613 = load float*, float** %549, align 8
  %550 = getelementptr inbounds float, float* %arrayptr93613, i64 %41
  store float %value_phi40, float* %550, align 4
  %551 = fsub float %value_phi83, %value_phi82
  %552 = fcmp une float %551, 0.000000e+00
  br i1 %552, label %L416, label %L492

oob147:                                           ; preds = %L441
  %errorbox148 = alloca i64, align 8
  store i64 %232, i64* %errorbox148, align 8
  call void @ijl_bounds_error_ints({}* %getfield143, i64* nonnull %errorbox148, i64 1)
  unreachable

idxend149:                                        ; preds = %L441
  %553 = bitcast {}* %getfield143 to float**
  %arrayptr151626 = load float*, float** %553, align 8
  %554 = getelementptr inbounds float, float* %arrayptr151626, i64 %231
  store float %value_phi83, float* %554, align 4
  %getfield153 = load atomic {}*, {}** %33 unordered, align 8
  %555 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %555, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %231, %arraylen155
  br i1 %inbounds156, label %idxend169, label %oob157

oob157:                                           ; preds = %idxend149
  %errorbox158 = alloca i64, align 8
  store i64 %232, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend169:                                        ; preds = %idxend149
  %556 = bitcast {}* %getfield153 to i64**
  %arrayptr161627 = load i64*, i64** %556, align 8
  %557 = getelementptr inbounds i64, i64* %arrayptr161627, i64 %231
  store i64 %arrayref, i64* %557, align 8
  store i64 %232, i64* %226, align 8
  br label %L455

oob281:                                           ; preds = %L545
  %errorbox282 = alloca i64, align 8
  store i64 %value_phi266, i64* %errorbox282, align 8
  call void @ijl_bounds_error_ints({}* %getfield277, i64* nonnull %errorbox282, i64 1)
  unreachable

idxend283:                                        ; preds = %L545
  %558 = bitcast {}* %getfield277 to float**
  %arrayptr285644 = load float*, float** %558, align 8
  %559 = getelementptr inbounds float, float* %arrayptr285644, i64 %302
  %arrayref286 = load float, float* %559, align 4
  %560 = fcmp ord float %arrayref286, 0.000000e+00
  %561 = bitcast {}* %getfield275 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr514 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %561, i64 0, i32 1
  %arraylen515 = load i64, i64* %arraylen_ptr514, align 8
  %.not683 = icmp eq i64 %arraylen515, 0
  br i1 %560, label %L608, label %L565

oob334:                                           ; preds = %L671.preheader
  %errorbox335650 = alloca [2 x i64], align 8
  %errorbox335650.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox335650, i64 0, i64 0
  store i64 1, i64* %errorbox335650.sub, align 8
  %562 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox335650, i64 0, i64 1
  store i64 %value_phi266, i64* %562, align 8
  call void @ijl_bounds_error_ints({}* %getfield315, i64* nonnull %errorbox335650.sub, i64 2)
  unreachable

oob364:                                           ; preds = %L930
  %errorbox365 = alloca i64, align 8
  store i64 %value_phi266, i64* %errorbox365, align 8
  call void @ijl_bounds_error_ints({}* %getfield360, i64* nonnull %errorbox365, i64 1)
  unreachable

idxend366:                                        ; preds = %L930
  %563 = bitcast {}* %getfield360 to float**
  %arrayptr368656 = load float*, float** %563, align 8
  %564 = getelementptr inbounds float, float* %arrayptr368656, i64 %302
  store float %value_phi313, float* %564, align 4
  %565 = fsub float %value_phi358, %value_phi357
  %566 = fcmp une float %565, 0.000000e+00
  br i1 %566, label %L938, label %L1014

oob420:                                           ; preds = %L963
  %errorbox421 = alloca i64, align 8
  store i64 %491, i64* %errorbox421, align 8
  call void @ijl_bounds_error_ints({}* %getfield416, i64* nonnull %errorbox421, i64 1)
  unreachable

idxend422:                                        ; preds = %L963
  %567 = bitcast {}* %getfield416 to float**
  %arrayptr424669 = load float*, float** %567, align 8
  %568 = getelementptr inbounds float, float* %arrayptr424669, i64 %490
  store float %value_phi358, float* %568, align 4
  %getfield426 = load atomic {}*, {}** %295 unordered, align 8
  %569 = bitcast {}* %getfield426 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr427 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %569, i64 0, i32 1
  %arraylen428 = load i64, i64* %arraylen_ptr427, align 8
  %inbounds429 = icmp ult i64 %490, %arraylen428
  br i1 %inbounds429, label %idxend442, label %oob430

oob430:                                           ; preds = %idxend422
  %errorbox431 = alloca i64, align 8
  store i64 %491, i64* %errorbox431, align 8
  call void @ijl_bounds_error_ints({}* %getfield426, i64* nonnull %errorbox431, i64 1)
  unreachable

idxend442:                                        ; preds = %idxend422
  %570 = bitcast {}* %getfield426 to i64**
  %arrayptr434670 = load i64*, i64** %570, align 8
  %571 = getelementptr inbounds i64, i64* %arrayptr434670, i64 %490
  store i64 %value_phi266, i64* %571, align 8
  store i64 %491, i64* %485, align 8
  br label %L977
}
