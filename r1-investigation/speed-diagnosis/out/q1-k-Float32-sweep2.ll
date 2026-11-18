define float @"julia__sweep!_1841"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(72) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(48) %3, i8 zeroext %4, [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* nocapture noundef nonnull readonly align 8 dereferenceable(40) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1808 = alloca [5 x {}*], align 16
  %gcframe1808.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1808 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct83 = alloca [1 x i64], align 8
  %newstruct118 = alloca [1 x i64], align 8
  %newstruct366 = alloca [1 x i64], align 8
  %newstruct399 = alloca [1 x i64], align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #12
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [5 x {}*]* %gcframe1808 to i64*
  store i64 12, i64* %9, align 16
  %10 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe1808.sub, {}*** %13, align 8
  %14 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 1, i64 0, i64 0
  %15 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 1, i64 0, i64 1
  %unbox = load i64, i64* %15, align 8
  %unbox1 = load i64, i64* %14, align 8
  %16 = sub i64 %unbox, %unbox1
  %17 = add i64 %16, 1
  %18 = call i64 @llvm.smax.i64(i64 %17, i64 0)
  %19 = bitcast {}* %3 to i8*
  %20 = load i8, i8* %19, align 8
  %21 = and i8 %20, 1
  %.not = icmp eq i8 %21, 0
  br i1 %.not, label %L553, label %L12

L12:                                              ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %19, i64 8
  %22 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %22 unordered, align 8
  %23 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield, {}** %23, align 16
  %24 = call nonnull {}* @"j__shuffle!_1843"({}* nonnull %getfield, i64 signext %18)
  %.not604 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not604, label %L1089, label %L30.preheader

L30.preheader:                                    ; preds = %L12
  %25 = bitcast {}* %24 to i64**
  %26 = bitcast [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5 to i64***
  %getfield121809 = load atomic i64**, i64*** %26 unordered, align 8
  %27 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 2
  %unbox13 = load i64, i64* %27, align 8
  %28 = bitcast {}* %1 to {}**
  %29 = bitcast {}* %0 to i8*
  %getfield_addr81 = getelementptr inbounds i8, i8* %29, i64 16
  %30 = bitcast i8* %getfield_addr81 to {}**
  %31 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct83, i64 0, i64 0
  %32 = bitcast {}* %0 to {}**
  %33 = bitcast {}* %1 to i8*
  %34 = getelementptr inbounds i8, i8* %33, i64 8
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %34 to float*
  %35 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct118, i64 0, i64 0
  %36 = getelementptr inbounds i8, i8* %29, i64 24
  %37 = bitcast i8* %36 to i64*
  %getfield_addr162 = getelementptr inbounds i8, i8* %29, i64 8
  %38 = bitcast i8* %getfield_addr162 to {}**
  %39 = and i8 %4, 1
  %.not621 = icmp eq i8 %39, 0
  br label %L30

L30:                                              ; preds = %L536, %L30.preheader
  %arrayref16945 = phi i64 [ %arrayref16944, %L536 ], [ undef, %L30.preheader ]
  %value_phi5 = phi i64 [ %290, %L536 ], [ 1, %L30.preheader ]
  %value_phi7 = phi float [ %289, %L536 ], [ 0.000000e+00, %L30.preheader ]
  %40 = add nsw i64 %value_phi5, -1
  %arrayptr606 = load i64*, i64** %25, align 8
  %41 = getelementptr inbounds i64, i64* %arrayptr606, i64 %40
  %arrayref = load i64, i64* %41, align 8
  %42 = add i64 %arrayref, -1
  %43 = add i64 %42, %unbox13
  %arrayptr15607 = load i64*, i64** %getfield121809, align 8
  %44 = getelementptr inbounds i64, i64* %arrayptr15607, i64 %43
  %arrayref16 = load i64, i64* %44, align 8
  %getfield18 = load atomic {}*, {}** %28 unordered, align 8
  %45 = bitcast {}* %getfield18 to {}**
  %getfield20 = load atomic {}*, {}** %45 unordered, align 8
  %46 = bitcast {}* %getfield18 to i8*
  %getfield_addr21 = getelementptr inbounds i8, i8* %46, i64 24
  %47 = bitcast i8* %getfield_addr21 to {}**
  %getfield22 = load atomic {}*, {}** %47 unordered, align 8
  %getfield_addr23 = getelementptr inbounds i8, i8* %46, i64 32
  %48 = bitcast i8* %getfield_addr23 to {}**
  %getfield24 = load atomic {}*, {}** %48 unordered, align 8
  %49 = add i64 %arrayref16, -1
  %50 = bitcast {}* %getfield24 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %50, i64 0, i32 1
  %arraylen = load i64, i64* %arraylen_ptr, align 8
  %inbounds = icmp ult i64 %49, %arraylen
  br i1 %inbounds, label %idxend, label %oob

L67:                                              ; preds = %idxend
  br i1 %.not645, label %L151, label %L81.lr.ph

L81.lr.ph:                                        ; preds = %L67
  %51 = bitcast {}* %getfield20 to {}**
  %arraysize_ptr = getelementptr inbounds {}*, {}** %51, i64 3
  %52 = bitcast {}** %arraysize_ptr to i64*
  %arraysize = load i64, i64* %52, align 8
  %53 = mul i64 %arraysize, %49
  %54 = bitcast {}* %getfield20 to float**
  %arrayptr37611 = load float*, float** %54, align 8
  %55 = bitcast {}* %getfield22 to float**
  %arrayptr40612 = load float*, float** %55, align 8
  %min.iters.check1518 = icmp ult i64 %arraylen250, 8
  br i1 %min.iters.check1518, label %scalar.ph1517, label %vector.ph1519

vector.ph1519:                                    ; preds = %L81.lr.ph
  %n.vec1521 = and i64 %arraylen250, 9223372036854775800
  br label %vector.body1524

vector.body1524:                                  ; preds = %vector.body1524, %vector.ph1519
  %index1525 = phi i64 [ 0, %vector.ph1519 ], [ %index.next1531, %vector.body1524 ]
  %vec.phi1526 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1519 ], [ %62, %vector.body1524 ]
  %vec.phi1527 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1519 ], [ %64, %vector.body1524 ]
  %vec.phi1528 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1519 ], [ %66, %vector.body1524 ]
  %56 = add i64 %53, %index1525
  %57 = getelementptr inbounds float, float* %arrayptr37611, i64 %56
  %58 = bitcast float* %57 to <8 x float>*
  %wide.load1529 = load <8 x float>, <8 x float>* %58, align 4
  %59 = getelementptr inbounds float, float* %arrayptr40612, i64 %index1525
  %60 = bitcast float* %59 to <8 x float>*
  %wide.load1530 = load <8 x float>, <8 x float>* %60, align 4
  %61 = fmul contract <8 x float> %wide.load1529, %wide.load1529
  %62 = fadd reassoc contract <8 x float> %vec.phi1526, %61
  %63 = fmul contract <8 x float> %wide.load1529, %wide.load1530
  %64 = fadd reassoc contract <8 x float> %vec.phi1527, %63
  %65 = fmul contract <8 x float> %wide.load1530, %wide.load1530
  %66 = fadd reassoc contract <8 x float> %vec.phi1528, %65
  %index.next1531 = add nuw i64 %index1525, 8
  %67 = icmp eq i64 %index.next1531, %n.vec1521
  br i1 %67, label %middle.block1516, label %vector.body1524

middle.block1516:                                 ; preds = %vector.body1524
  %68 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %66)
  %69 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %64)
  %70 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %62)
  %cmp.n1523 = icmp eq i64 %arraylen250, %n.vec1521
  br i1 %cmp.n1523, label %L151, label %scalar.ph1517

scalar.ph1517:                                    ; preds = %middle.block1516, %L81.lr.ph
  %bc.resume.val1522 = phi i64 [ %n.vec1521, %middle.block1516 ], [ 0, %L81.lr.ph ]
  %bc.merge.rdx1532 = phi float [ %70, %middle.block1516 ], [ 0.000000e+00, %L81.lr.ph ]
  %bc.merge.rdx1533 = phi float [ %69, %middle.block1516 ], [ 0.000000e+00, %L81.lr.ph ]
  %bc.merge.rdx1534 = phi float [ %68, %middle.block1516 ], [ 0.000000e+00, %L81.lr.ph ]
  br label %L81

L81:                                              ; preds = %L81, %scalar.ph1517
  %value_phi35867 = phi float [ %bc.merge.rdx1532, %scalar.ph1517 ], [ %75, %L81 ]
  %value_phi34866 = phi i64 [ %bc.resume.val1522, %scalar.ph1517 ], [ %80, %L81 ]
  %value_phi33865 = phi float [ %bc.merge.rdx1533, %scalar.ph1517 ], [ %77, %L81 ]
  %value_phi32864 = phi float [ %bc.merge.rdx1534, %scalar.ph1517 ], [ %79, %L81 ]
  %71 = add i64 %53, %value_phi34866
  %72 = getelementptr inbounds float, float* %arrayptr37611, i64 %71
  %arrayref38 = load float, float* %72, align 4
  %73 = getelementptr inbounds float, float* %arrayptr40612, i64 %value_phi34866
  %arrayref41 = load float, float* %73, align 4
  %74 = fmul contract float %arrayref38, %arrayref38
  %75 = fadd reassoc contract float %value_phi35867, %74
  %76 = fmul contract float %arrayref38, %arrayref41
  %77 = fadd reassoc contract float %value_phi33865, %76
  %78 = fmul contract float %arrayref41, %arrayref41
  %79 = fadd reassoc contract float %value_phi32864, %78
  %80 = add nuw nsw i64 %value_phi34866, 1
  %exitcond.not = icmp eq i64 %80, %arraylen250
  br i1 %exitcond.not, label %L151, label %L81

L110:                                             ; preds = %idxend
  br i1 %.not645, label %L151, label %L123.lr.ph

L123.lr.ph:                                       ; preds = %L110
  %81 = bitcast {}* %getfield20 to {}**
  %arraysize_ptr256 = getelementptr inbounds {}*, {}** %81, i64 3
  %82 = bitcast {}** %arraysize_ptr256 to i64*
  %arraysize257 = load i64, i64* %82, align 8
  %83 = mul i64 %arraysize257, %49
  %84 = bitcast {}* %getfield20 to float**
  %arrayptr260647 = load float*, float** %84, align 8
  %85 = bitcast {}* %getfield22 to float**
  %arrayptr263648 = load float*, float** %85, align 8
  %min.iters.check1495 = icmp ult i64 %arraylen250, 16
  br i1 %min.iters.check1495, label %scalar.ph1494, label %vector.ph1496

vector.ph1496:                                    ; preds = %L123.lr.ph
  %n.vec1498 = and i64 %arraylen250, 9223372036854775792
  br label %vector.body1501

vector.body1501:                                  ; preds = %vector.body1501, %vector.ph1496
  %index1502 = phi i64 [ 0, %vector.ph1496 ], [ %index.next1511, %vector.body1501 ]
  %vec.phi1503 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %97, %vector.body1501 ]
  %vec.phi1504 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %98, %vector.body1501 ]
  %vec.phi1505 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %101, %vector.body1501 ]
  %vec.phi1506 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %102, %vector.body1501 ]
  %86 = add i64 %83, %index1502
  %87 = getelementptr inbounds float, float* %arrayptr260647, i64 %86
  %88 = bitcast float* %87 to <8 x float>*
  %wide.load1507 = load <8 x float>, <8 x float>* %88, align 4
  %89 = getelementptr inbounds float, float* %87, i64 8
  %90 = bitcast float* %89 to <8 x float>*
  %wide.load1508 = load <8 x float>, <8 x float>* %90, align 4
  %91 = getelementptr inbounds float, float* %arrayptr263648, i64 %index1502
  %92 = bitcast float* %91 to <8 x float>*
  %wide.load1509 = load <8 x float>, <8 x float>* %92, align 4
  %93 = getelementptr inbounds float, float* %91, i64 8
  %94 = bitcast float* %93 to <8 x float>*
  %wide.load1510 = load <8 x float>, <8 x float>* %94, align 4
  %95 = fmul contract <8 x float> %wide.load1507, %wide.load1509
  %96 = fmul contract <8 x float> %wide.load1508, %wide.load1510
  %97 = fadd reassoc contract <8 x float> %vec.phi1503, %95
  %98 = fadd reassoc contract <8 x float> %vec.phi1504, %96
  %99 = fmul contract <8 x float> %wide.load1509, %wide.load1509
  %100 = fmul contract <8 x float> %wide.load1510, %wide.load1510
  %101 = fadd reassoc contract <8 x float> %vec.phi1505, %99
  %102 = fadd reassoc contract <8 x float> %vec.phi1506, %100
  %index.next1511 = add nuw i64 %index1502, 16
  %103 = icmp eq i64 %index.next1511, %n.vec1498
  br i1 %103, label %middle.block1493, label %vector.body1501

middle.block1493:                                 ; preds = %vector.body1501
  %bin.rdx1514 = fadd reassoc contract <8 x float> %102, %101
  %104 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1514)
  %bin.rdx1512 = fadd reassoc contract <8 x float> %98, %97
  %105 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1512)
  %cmp.n1500 = icmp eq i64 %arraylen250, %n.vec1498
  br i1 %cmp.n1500, label %L151, label %scalar.ph1494

scalar.ph1494:                                    ; preds = %middle.block1493, %L123.lr.ph
  %bc.resume.val1499 = phi i64 [ %n.vec1498, %middle.block1493 ], [ 0, %L123.lr.ph ]
  %bc.merge.rdx1513 = phi float [ %105, %middle.block1493 ], [ 0.000000e+00, %L123.lr.ph ]
  %bc.merge.rdx1515 = phi float [ %104, %middle.block1493 ], [ 0.000000e+00, %L123.lr.ph ]
  br label %L123

L123:                                             ; preds = %L123, %scalar.ph1494
  %value_phi255873 = phi i64 [ %bc.resume.val1499, %scalar.ph1494 ], [ %113, %L123 ]
  %value_phi254872 = phi float [ %bc.merge.rdx1513, %scalar.ph1494 ], [ %110, %L123 ]
  %value_phi253871 = phi float [ %bc.merge.rdx1515, %scalar.ph1494 ], [ %112, %L123 ]
  %106 = add i64 %83, %value_phi255873
  %107 = getelementptr inbounds float, float* %arrayptr260647, i64 %106
  %arrayref261 = load float, float* %107, align 4
  %108 = getelementptr inbounds float, float* %arrayptr263648, i64 %value_phi255873
  %arrayref264 = load float, float* %108, align 4
  %109 = fmul contract float %arrayref261, %arrayref264
  %110 = fadd reassoc contract float %value_phi254872, %109
  %111 = fmul contract float %arrayref264, %arrayref264
  %112 = fadd reassoc contract float %value_phi253871, %111
  %113 = add nuw nsw i64 %value_phi255873, 1
  %exitcond1047.not = icmp eq i64 %113, %arraylen250
  br i1 %exitcond1047.not, label %L151, label %L123

L151:                                             ; preds = %L123, %middle.block1493, %L110, %L81, %middle.block1516, %L67
  %value_phi48 = phi float [ 0.000000e+00, %L67 ], [ 0.000000e+00, %L110 ], [ %104, %middle.block1493 ], [ %68, %middle.block1516 ], [ %112, %L123 ], [ %79, %L81 ]
  %value_phi49 = phi float [ 0.000000e+00, %L67 ], [ 0.000000e+00, %L110 ], [ %105, %middle.block1493 ], [ %69, %middle.block1516 ], [ %110, %L123 ], [ %77, %L81 ]
  %value_phi50 = phi float [ 0.000000e+00, %L67 ], [ %arrayref27, %L110 ], [ %arrayref27, %middle.block1493 ], [ %70, %middle.block1516 ], [ %arrayref27, %L123 ], [ %75, %L81 ]
  %114 = fsub float %value_phi48, %value_phi48
  %115 = fcmp uno float %114, 0.000000e+00
  br i1 %115, label %L156, label %L158

L156:                                             ; preds = %L151
  %116 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %116, align 8
  %117 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %117, align 16
  store {}* %getfield22, {}** %23, align 16
  call void @j__check_residual_1852({}* nonnull %getfield22, i64 signext %arrayref16)
  br label %L158

L158:                                             ; preds = %L156, %L151
  %118 = fcmp une float %value_phi50, 0.000000e+00
  br i1 %118, label %L199, label %L160

L160:                                             ; preds = %L158
  %getfield52 = load atomic {}*, {}** %45 unordered, align 8
  %119 = bitcast {}* %getfield52 to {}**
  %arraysize_ptr53 = getelementptr inbounds {}*, {}** %119, i64 3
  %120 = bitcast {}** %arraysize_ptr53 to i64*
  %arraysize54 = load i64, i64* %120, align 8
  %.not613.not = icmp eq i64 %arraysize54, 0
  br i1 %.not613.not, label %L199, label %L173.preheader

L173.preheader:                                   ; preds = %L160
  %arraysize_ptr67 = getelementptr inbounds {}*, {}** %119, i64 4
  %121 = bitcast {}** %arraysize_ptr67 to i64*
  %arraysize68 = load i64, i64* %121, align 8
  %inbounds69 = icmp ult i64 %49, %arraysize68
  %122 = mul i64 %arraysize54, %49
  %123 = bitcast {}* %getfield52 to float**
  %arrayptr74615 = load float*, float** %123, align 8
  %inbounds69.fr = freeze i1 %inbounds69
  br i1 %inbounds69.fr, label %ib.us, label %oob70

ib.us:                                            ; preds = %L179.us, %L173.preheader
  %value_phi59.us = phi i64 [ %128, %L179.us ], [ 1, %L173.preheader ]
  %124 = add nsw i64 %value_phi59.us, -1
  %125 = add i64 %122, %124
  %126 = getelementptr inbounds float, float* %arrayptr74615, i64 %125
  %arrayref75.us = load float, float* %126, align 4
  %127 = fcmp une float %arrayref75.us, 0.000000e+00
  br i1 %127, label %L195.split.us, label %L179.us

L179.us:                                          ; preds = %ib.us
  %128 = add nuw nsw i64 %value_phi59.us, 1
  %129 = icmp ult i64 %value_phi59.us, %arraysize54
  br i1 %129, label %ib.us, label %L199

L195.split.us:                                    ; preds = %ib.us
  store {}* inttoptr (i64 135794572797712 to {}*), {}** %6, align 8
  %130 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %130)
  unreachable

L199:                                             ; preds = %L179.us, %L160, %L158
  %131 = fsub float %value_phi50, %value_phi50
  %132 = fcmp uno float %131, 0.000000e+00
  br i1 %132, label %L514, label %L204

L204:                                             ; preds = %L199
  %getfield82 = load atomic {}*, {}** %30 unordered, align 8
  %133 = bitcast {}* %getfield82 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr84 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %133, i64 0, i32 1
  %arraylen85 = load i64, i64* %arraylen_ptr84, align 8
  %.not617 = icmp ult i64 %49, %arraylen85
  br i1 %.not617, label %L218, label %L215

L215:                                             ; preds = %L204
  store i64 %arrayref16, i64* %31, align 8
  store {}* %getfield82, {}** %23, align 16
  call void @j_throw_boundserror_1847({}* nonnull %getfield82, [1 x i64]* nocapture readonly %newstruct83) #2
  unreachable

L218:                                             ; preds = %L204
  %134 = bitcast {}* %getfield82 to i64**
  %arrayptr90618 = load i64*, i64** %134, align 8
  %135 = getelementptr inbounds i64, i64* %arrayptr90618, i64 %49
  %arrayref91 = load i64, i64* %135, align 8
  %.not619 = icmp eq i64 %arrayref91, 0
  br i1 %.not619, label %L228, label %L223

L223:                                             ; preds = %L218
  %136 = bitcast {}* %0 to float***
  %getfield2411810 = load atomic float**, float*** %136 unordered, align 8
  %137 = add i64 %arrayref91, -1
  %arrayptr243644 = load float*, float** %getfield2411810, align 8
  %138 = getelementptr inbounds float, float* %arrayptr243644, i64 %137
  %arrayref244 = load float, float* %138, align 4
  br label %L228

L228:                                             ; preds = %L223, %L218
  %value_phi92 = phi float [ %arrayref244, %L223 ], [ 0.000000e+00, %L218 ]
  br i1 %118, label %L232, label %L230

L230:                                             ; preds = %L228
  %139 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %139, align 8
  %140 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %140, align 16
  %141 = call float @j__coordinate_minimizer_1845({ double }* nocapture nonnull readonly %2, float %value_phi92, i64 signext %arrayref16)
  br label %L432

L232:                                             ; preds = %L228
  %getfield184 = load atomic {}*, {}** %28 unordered, align 8
  %142 = bitcast {}* %getfield184 to i8*
  %getfield_addr185 = getelementptr inbounds i8, i8* %142, i64 24
  %143 = bitcast i8* %getfield_addr185 to {}**
  %getfield186 = load atomic {}*, {}** %143 unordered, align 8
  %144 = bitcast {}* %getfield186 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr187 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %144, i64 0, i32 1
  %arraylen188 = load i64, i64* %arraylen_ptr187, align 8
  %145 = sitofp i64 %arraylen188 to float
  %146 = fmul float %145, 0x3980000000000000
  %147 = fcmp ole float %146, %value_phi50
  %148 = fcmp ord float %114, 0.000000e+00
  %149 = fcmp ole float %146, %value_phi48
  %150 = and i1 %148, %149
  %151 = and i1 %147, %150
  br i1 %151, label %L251, label %L429

L251:                                             ; preds = %L232
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %152 = fcmp uge float %value_phi50, 0.000000e+00
  br i1 %152, label %L257, label %L255

L255:                                             ; preds = %L251
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %value_phi50) #2
  unreachable

L257:                                             ; preds = %L251
  %153 = call float @llvm.sqrt.f32(float %value_phi50)
  %154 = fcmp ugt float %153, %aggregate_load_box.sroa.0.0.copyload
  br i1 %154, label %L262, label %L432

L262:                                             ; preds = %L257
  %155 = fdiv float %value_phi49, %value_phi50
  %156 = fadd float %155, %value_phi92
  %157 = fmul float %value_phi49, %155
  %158 = fsub float %value_phi48, %157
  %159 = fmul float %value_phi48, 6.250000e-02
  %160 = fcmp uge float %158, %159
  br i1 %160, label %L317, label %L269

L269:                                             ; preds = %L262
  %.not635 = icmp eq i64 %arraylen188, 0
  br i1 %.not635, label %L306, label %L283.lr.ph

L283.lr.ph:                                       ; preds = %L269
  %161 = bitcast {}* %getfield184 to {}**
  %getfield193 = load atomic {}*, {}** %161 unordered, align 8
  %162 = bitcast {}* %getfield186 to float**
  %arrayptr203637 = load float*, float** %162, align 8
  %163 = bitcast {}* %getfield193 to {}**
  %arraysize_ptr205 = getelementptr inbounds {}*, {}** %163, i64 3
  %164 = bitcast {}** %arraysize_ptr205 to i64*
  %arraysize206 = load i64, i64* %164, align 8
  %165 = mul i64 %arraysize206, %49
  %166 = bitcast {}* %getfield193 to float**
  %arrayptr209638 = load float*, float** %166, align 8
  %min.iters.check1475 = icmp ult i64 %arraylen188, 16
  br i1 %min.iters.check1475, label %scalar.ph1474, label %vector.ph1476

vector.ph1476:                                    ; preds = %L283.lr.ph
  %n.vec1478 = and i64 %arraylen188, 9223372036854775792
  %broadcast.splatinsert1488 = insertelement <8 x float> poison, float %155, i64 0
  %broadcast.splat1489 = shufflevector <8 x float> %broadcast.splatinsert1488, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1481

vector.body1481:                                  ; preds = %vector.body1481, %vector.ph1476
  %index1482 = phi i64 [ 0, %vector.ph1476 ], [ %index.next1492, %vector.body1481 ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1476 ], [ %182, %vector.body1481 ]
  %vec.phi1483 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1476 ], [ %183, %vector.body1481 ]
  %167 = getelementptr inbounds float, float* %arrayptr203637, i64 %index1482
  %168 = bitcast float* %167 to <8 x float>*
  %wide.load1484 = load <8 x float>, <8 x float>* %168, align 4
  %169 = getelementptr inbounds float, float* %167, i64 8
  %170 = bitcast float* %169 to <8 x float>*
  %wide.load1485 = load <8 x float>, <8 x float>* %170, align 4
  %171 = add i64 %165, %index1482
  %172 = getelementptr inbounds float, float* %arrayptr209638, i64 %171
  %173 = bitcast float* %172 to <8 x float>*
  %wide.load1486 = load <8 x float>, <8 x float>* %173, align 4
  %174 = getelementptr inbounds float, float* %172, i64 8
  %175 = bitcast float* %174 to <8 x float>*
  %wide.load1487 = load <8 x float>, <8 x float>* %175, align 4
  %176 = fmul <8 x float> %broadcast.splat1489, %wide.load1486
  %177 = fmul <8 x float> %broadcast.splat1489, %wide.load1487
  %178 = fsub <8 x float> %wide.load1484, %176
  %179 = fsub <8 x float> %wide.load1485, %177
  %180 = fmul contract <8 x float> %178, %178
  %181 = fmul contract <8 x float> %179, %179
  %182 = fadd reassoc contract <8 x float> %vec.phi, %180
  %183 = fadd reassoc contract <8 x float> %vec.phi1483, %181
  %index.next1492 = add nuw i64 %index1482, 16
  %184 = icmp eq i64 %index.next1492, %n.vec1478
  br i1 %184, label %middle.block1473, label %vector.body1481

middle.block1473:                                 ; preds = %vector.body1481
  %bin.rdx = fadd reassoc contract <8 x float> %183, %182
  %185 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n1480 = icmp eq i64 %arraylen188, %n.vec1478
  br i1 %cmp.n1480, label %L306, label %scalar.ph1474

scalar.ph1474:                                    ; preds = %middle.block1473, %L283.lr.ph
  %bc.resume.val1479 = phi i64 [ %n.vec1478, %middle.block1473 ], [ 0, %L283.lr.ph ]
  %bc.merge.rdx = phi float [ %185, %middle.block1473 ], [ 0.000000e+00, %L283.lr.ph ]
  br label %L283

L283:                                             ; preds = %L283, %scalar.ph1474
  %value_phi201878 = phi i64 [ %bc.resume.val1479, %scalar.ph1474 ], [ %193, %L283 ]
  %value_phi200877 = phi float [ %bc.merge.rdx, %scalar.ph1474 ], [ %192, %L283 ]
  %186 = getelementptr inbounds float, float* %arrayptr203637, i64 %value_phi201878
  %arrayref204 = load float, float* %186, align 4
  %187 = add i64 %165, %value_phi201878
  %188 = getelementptr inbounds float, float* %arrayptr209638, i64 %187
  %arrayref210 = load float, float* %188, align 4
  %189 = fmul float %155, %arrayref210
  %190 = fsub float %arrayref204, %189
  %191 = fmul contract float %190, %190
  %192 = fadd reassoc contract float %value_phi200877, %191
  %193 = add nuw nsw i64 %value_phi201878, 1
  %exitcond1048.not = icmp eq i64 %193, %arraylen188
  br i1 %exitcond1048.not, label %L306, label %L283

L306:                                             ; preds = %L283, %middle.block1473, %L269
  %value_phi212 = phi float [ 0.000000e+00, %L269 ], [ %185, %middle.block1473 ], [ %192, %L283 ]
  %194 = fsub float %value_phi212, %value_phi212
  %195 = fcmp uno float %194, 0.000000e+00
  %196 = fcmp ugt float %146, %value_phi212
  %197 = or i1 %196, %195
  br i1 %197, label %L315, label %L317

L315:                                             ; preds = %L306
  %198 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %198, align 8
  %199 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %199, align 16
  %200 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi92, i64 signext %arrayref16)
  br label %L432

L317:                                             ; preds = %L306, %L262
  %value_phi214 = phi float [ %158, %L262 ], [ %value_phi212, %L306 ]
  %201 = fcmp uge float %value_phi214, 0.000000e+00
  br i1 %201, label %L322, label %L320

L320:                                             ; preds = %L317
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %value_phi214) #2
  unreachable

L322:                                             ; preds = %L317
  %202 = call float @llvm.sqrt.f32(float %value_phi214)
  %203 = fsub float %153, %aggregate_load_box.sroa.0.0.copyload
  %204 = fcmp uge float %203, 0.000000e+00
  br i1 %204, label %L329, label %L327

L327:                                             ; preds = %L322
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %203) #2
  unreachable

L329:                                             ; preds = %L322
  %205 = fadd float %153, %aggregate_load_box.sroa.0.0.copyload
  %206 = fcmp uge float %205, 0.000000e+00
  br i1 %206, label %L336, label %L334

L334:                                             ; preds = %L329
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %205) #2
  unreachable

L336:                                             ; preds = %L329
  %207 = call float @llvm.sqrt.f32(float %203)
  %208 = call float @llvm.sqrt.f32(float %205)
  %209 = fmul float %207, %208
  %210 = fmul float %153, %209
  %211 = fdiv float %202, %210
  %212 = fmul float %aggregate_load_box.sroa.0.0.copyload, %211
  %213 = fcmp oge float %210, 0x3810000000000000
  %214 = fcmp oge float %211, 0x3810000000000000
  %215 = fcmp ole float %211, 0x47EFFFFFE0000000
  %narrow = and i1 %214, %215
  %216 = and i1 %213, %narrow
  %217 = fcmp oge float %212, 0x3810000000000000
  %218 = fcmp ole float %212, 0x47EFFFFFE0000000
  %narrow639 = and i1 %217, %218
  %219 = and i1 %216, %narrow639
  br i1 %219, label %L370, label %L427

L370:                                             ; preds = %L336
  %220 = fneg float %212
  %.inv641 = fcmp ogt float %156, %220
  %221 = select i1 %.inv641, float %156, float %220
  %.inv642 = fcmp olt float %221, %212
  %222 = select i1 %.inv642, float %221, float %212
  %223 = fsub float %156, %222
  %224 = fadd float %223, 0.000000e+00
  br label %L432

L427:                                             ; preds = %L336
  %225 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %225, align 8
  %226 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %226, align 16
  %227 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi92, i64 signext %arrayref16)
  br label %L432

L429:                                             ; preds = %L232
  %228 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %228, align 8
  %229 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %229, align 16
  %230 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi92, i64 signext %arrayref16)
  br label %L432

L432:                                             ; preds = %L429, %L427, %L370, %L315, %L257, %L230
  %value_phi93 = phi float [ %141, %L230 ], [ %200, %L315 ], [ %227, %L427 ], [ %230, %L429 ], [ 0.000000e+00, %L257 ], [ %224, %L370 ]
  %getfield95 = load atomic {}*, {}** %48 unordered, align 8
  %231 = bitcast {}* %getfield95 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr96 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %231, i64 0, i32 1
  %arraylen97 = load i64, i64* %arraylen_ptr96, align 8
  %inbounds98 = icmp ult i64 %49, %arraylen97
  br i1 %inbounds98, label %idxend101, label %oob99

L440:                                             ; preds = %idxend101
  %getfield117 = load atomic {}*, {}** %30 unordered, align 8
  %232 = bitcast {}* %getfield117 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr119 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %232, i64 0, i32 1
  %arraylen120 = load i64, i64* %arraylen_ptr119, align 8
  %.not623 = icmp ult i64 %49, %arraylen120
  br i1 %.not623, label %L454, label %L451

L451:                                             ; preds = %L440
  store i64 %arrayref16, i64* %35, align 8
  store {}* %getfield117, {}** %23, align 16
  call void @j_throw_boundserror_1847({}* nonnull %getfield117, [1 x i64]* nocapture readonly %newstruct118) #2
  unreachable

L454:                                             ; preds = %L440
  %233 = bitcast {}* %getfield117 to i64**
  %arrayptr125624 = load i64*, i64** %233, align 8
  %234 = getelementptr inbounds i64, i64* %arrayptr125624, i64 %49
  %arrayref126 = load i64, i64* %234, align 8
  %.not625 = icmp eq i64 %arrayref126, 0
  br i1 %.not625, label %L462, label %L459

L459:                                             ; preds = %L454
  %235 = bitcast {}* %0 to float***
  %getfield1281811 = load atomic float**, float*** %235 unordered, align 8
  %236 = add i64 %arrayref126, -1
  %arrayptr130626 = load float*, float** %getfield1281811, align 8
  %237 = getelementptr inbounds float, float* %arrayptr130626, i64 %236
  store float %value_phi93, float* %237, align 4
  br label %L479

L462:                                             ; preds = %L454
  %238 = fcmp oeq float %value_phi93, 0.000000e+00
  br i1 %238, label %L479, label %L465

L465:                                             ; preds = %L462
  %239 = load i64, i64* %37, align 8
  %240 = add i64 %239, 1
  store i64 %240, i64* %37, align 8
  %getfield153 = load atomic {}*, {}** %32 unordered, align 8
  %241 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %241, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %239, %arraylen155
  br i1 %inbounds156, label %idxend159, label %oob157

L479:                                             ; preds = %idxend179, %L462, %L459
  %getfield132 = load atomic {}*, {}** %47 unordered, align 8
  %242 = bitcast {}* %getfield132 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr135 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %242, i64 0, i32 1
  %arraylen136 = load i64, i64* %arraylen_ptr135, align 8
  %.not627 = icmp eq i64 %arraylen136, 0
  br i1 %.not627, label %L516, label %L492.lr.ph

L492.lr.ph:                                       ; preds = %L479
  %getfield134 = load atomic {}*, {}** %45 unordered, align 8
  %243 = bitcast {}* %getfield132 to float**
  %arrayptr141629 = load float*, float** %243, align 8
  %244 = bitcast {}* %getfield134 to {}**
  %arraysize_ptr143 = getelementptr inbounds {}*, {}** %244, i64 3
  %245 = bitcast {}** %arraysize_ptr143 to i64*
  %arraysize144 = load i64, i64* %245, align 8
  %246 = mul i64 %arraysize144, %49
  %247 = bitcast {}* %getfield134 to float**
  %arrayptr147630 = load float*, float** %247, align 8
  %min.iters.check = icmp ult i64 %arraylen136, 32
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L492.lr.ph
  %scevgep = getelementptr float, float* %arrayptr141629, i64 %arraylen136
  %scevgep1456 = getelementptr float, float* %arrayptr147630, i64 %246
  %248 = add i64 %arraylen136, %246
  %scevgep1458 = getelementptr float, float* %arrayptr147630, i64 %248
  %bound0 = icmp ult float* %arrayptr141629, %scevgep1458
  %bound1 = icmp ult float* %scevgep1456, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen136, 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %561, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %249 = getelementptr inbounds float, float* %arrayptr141629, i64 %index
  %250 = bitcast float* %249 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %250, align 4
  %251 = getelementptr inbounds float, float* %249, i64 8
  %252 = bitcast float* %251 to <8 x float>*
  %wide.load1460 = load <8 x float>, <8 x float>* %252, align 4
  %253 = getelementptr inbounds float, float* %249, i64 16
  %254 = bitcast float* %253 to <8 x float>*
  %wide.load1461 = load <8 x float>, <8 x float>* %254, align 4
  %255 = getelementptr inbounds float, float* %249, i64 24
  %256 = bitcast float* %255 to <8 x float>*
  %wide.load1462 = load <8 x float>, <8 x float>* %256, align 4
  %257 = add i64 %246, %index
  %258 = getelementptr inbounds float, float* %arrayptr147630, i64 %257
  %259 = bitcast float* %258 to <8 x float>*
  %wide.load1463 = load <8 x float>, <8 x float>* %259, align 4
  %260 = getelementptr inbounds float, float* %258, i64 8
  %261 = bitcast float* %260 to <8 x float>*
  %wide.load1464 = load <8 x float>, <8 x float>* %261, align 4
  %262 = getelementptr inbounds float, float* %258, i64 16
  %263 = bitcast float* %262 to <8 x float>*
  %wide.load1465 = load <8 x float>, <8 x float>* %263, align 4
  %264 = getelementptr inbounds float, float* %258, i64 24
  %265 = bitcast float* %264 to <8 x float>*
  %wide.load1466 = load <8 x float>, <8 x float>* %265, align 4
  %266 = fmul <8 x float> %broadcast.splat, %wide.load1463
  %267 = fmul <8 x float> %broadcast.splat, %wide.load1464
  %268 = fmul <8 x float> %broadcast.splat, %wide.load1465
  %269 = fmul <8 x float> %broadcast.splat, %wide.load1466
  %270 = fsub <8 x float> %wide.load, %266
  %271 = fsub <8 x float> %wide.load1460, %267
  %272 = fsub <8 x float> %wide.load1461, %268
  %273 = fsub <8 x float> %wide.load1462, %269
  store <8 x float> %270, <8 x float>* %250, align 4
  store <8 x float> %271, <8 x float>* %252, align 4
  store <8 x float> %272, <8 x float>* %254, align 4
  store <8 x float> %273, <8 x float>* %256, align 4
  %index.next = add nuw i64 %index, 32
  %274 = icmp eq i64 %index.next, %n.vec
  br i1 %274, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen136, %n.vec
  br i1 %cmp.n, label %L516, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L492.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L492.lr.ph ], [ 0, %vector.memcheck ]
  br label %L492

L492:                                             ; preds = %L492, %scalar.ph
  %value_phi139881 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %280, %L492 ]
  %275 = getelementptr inbounds float, float* %arrayptr141629, i64 %value_phi139881
  %arrayref142 = load float, float* %275, align 4
  %276 = add i64 %246, %value_phi139881
  %277 = getelementptr inbounds float, float* %arrayptr147630, i64 %276
  %arrayref148 = load float, float* %277, align 4
  %278 = fmul float %561, %arrayref148
  %279 = fsub float %arrayref142, %278
  store float %279, float* %275, align 4
  %280 = add nuw nsw i64 %value_phi139881, 1
  %exitcond1049.not = icmp eq i64 %280, %arraylen136
  br i1 %exitcond1049.not, label %L516, label %L492

L514:                                             ; preds = %L199
  call void @j__refuse_curvature_1851(i64 signext %arrayref16) #2
  unreachable

L516:                                             ; preds = %idxend101, %L492, %middle.block, %L479
  %arrayref16944 = phi i64 [ %arrayref16, %L479 ], [ %arrayref16945, %idxend101 ], [ %arrayref16, %middle.block ], [ %arrayref16, %L492 ]
  %281 = call float @llvm.fabs.f32(float %561)
  %282 = fcmp oeq float %561, 0.000000e+00
  %or.cond = select i1 %.not621, i1 true, i1 %282
  br i1 %or.cond, label %L527, label %L522

L522:                                             ; preds = %L516
  %getfield106 = load atomic {}*, {}** %28 unordered, align 8
  %283 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %283, align 8
  store {}* %getfield106, {}** %23, align 16
  %284 = call float @j_coordinate_scale_1846({}* nonnull %getfield106, {}* nonnull %0, i64 signext %arrayref16)
  %285 = fmul float %281, %284
  br label %L527

L527:                                             ; preds = %L522, %L516
  %value_phi107 = phi float [ %285, %L522 ], [ %281, %L516 ]
  %286 = fsub float %value_phi107, %value_phi107
  %287 = fcmp uno float %286, 0.000000e+00
  br i1 %287, label %L533, label %L536

L533:                                             ; preds = %L527
  store {}* inttoptr (i64 135794568852048 to {}*), {}** %6, align 8
  %288 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %288)
  unreachable

L536:                                             ; preds = %L527
  %.inv = fcmp olt float %value_phi7, %value_phi107
  %289 = select i1 %.inv, float %value_phi107, float %value_phi7
  %.not622.not = icmp eq i64 %value_phi5, %18
  %290 = add nuw i64 %value_phi5, 1
  br i1 %.not622.not, label %L1089.loopexit699, label %L30

L553:                                             ; preds = %top
  %.not649 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not649, label %L1089, label %L569.preheader

L569.preheader:                                   ; preds = %L553
  %291 = bitcast [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5 to i64***
  %getfield2831812 = load atomic i64**, i64*** %291 unordered, align 8
  %292 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 2
  %unbox284 = load i64, i64* %292, align 8
  %293 = bitcast {}* %1 to {}**
  %294 = bitcast {}* %0 to i8*
  %getfield_addr364 = getelementptr inbounds i8, i8* %294, i64 16
  %295 = bitcast i8* %getfield_addr364 to {}**
  %296 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct366, i64 0, i64 0
  %297 = bitcast {}* %0 to {}**
  %298 = bitcast {}* %1 to i8*
  %299 = getelementptr inbounds i8, i8* %298, i64 8
  %aggregate_load_box470.sroa.0.0..sroa_idx = bitcast i8* %299 to float*
  %300 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct399, i64 0, i64 0
  %301 = getelementptr inbounds i8, i8* %294, i64 24
  %302 = bitcast i8* %301 to i64*
  %getfield_addr443 = getelementptr inbounds i8, i8* %294, i64 8
  %303 = bitcast i8* %getfield_addr443 to {}**
  %304 = and i8 %4, 1
  %.not665 = icmp eq i8 %304, 0
  br label %L569

L569:                                             ; preds = %L1074, %L569.preheader
  %arrayref2871006 = phi i64 [ %arrayref2871005, %L1074 ], [ undef, %L569.preheader ]
  %value_phi275 = phi i64 [ %551, %L1074 ], [ 1, %L569.preheader ]
  %value_phi277 = phi float [ %550, %L1074 ], [ 0.000000e+00, %L569.preheader ]
  %305 = add nsw i64 %value_phi275, -1
  %306 = add i64 %305, %unbox284
  %arrayptr286651 = load i64*, i64** %getfield2831812, align 8
  %307 = getelementptr inbounds i64, i64* %arrayptr286651, i64 %306
  %arrayref287 = load i64, i64* %307, align 8
  %getfield289 = load atomic {}*, {}** %293 unordered, align 8
  %308 = bitcast {}* %getfield289 to {}**
  %getfield291 = load atomic {}*, {}** %308 unordered, align 8
  %309 = bitcast {}* %getfield289 to i8*
  %getfield_addr292 = getelementptr inbounds i8, i8* %309, i64 24
  %310 = bitcast i8* %getfield_addr292 to {}**
  %getfield293 = load atomic {}*, {}** %310 unordered, align 8
  %getfield_addr294 = getelementptr inbounds i8, i8* %309, i64 32
  %311 = bitcast i8* %getfield_addr294 to {}**
  %getfield295 = load atomic {}*, {}** %311 unordered, align 8
  %312 = add i64 %arrayref287, -1
  %313 = bitcast {}* %getfield295 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr296 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %313, i64 0, i32 1
  %arraylen297 = load i64, i64* %arraylen_ptr296, align 8
  %inbounds298 = icmp ult i64 %312, %arraylen297
  br i1 %inbounds298, label %idxend301, label %oob299

L605:                                             ; preds = %idxend301
  br i1 %.not691, label %L689, label %L619.lr.ph

L619.lr.ph:                                       ; preds = %L605
  %314 = bitcast {}* %getfield291 to {}**
  %arraysize_ptr313 = getelementptr inbounds {}*, {}** %314, i64 3
  %315 = bitcast {}** %arraysize_ptr313 to i64*
  %arraysize314 = load i64, i64* %315, align 8
  %316 = mul i64 %arraysize314, %312
  %317 = bitcast {}* %getfield291 to float**
  %arrayptr317655 = load float*, float** %317, align 8
  %318 = bitcast {}* %getfield293 to float**
  %arrayptr320656 = load float*, float** %318, align 8
  %min.iters.check1621 = icmp ult i64 %arraylen533, 8
  br i1 %min.iters.check1621, label %scalar.ph1620, label %vector.ph1622

vector.ph1622:                                    ; preds = %L619.lr.ph
  %n.vec1624 = and i64 %arraylen533, 9223372036854775800
  br label %vector.body1627

vector.body1627:                                  ; preds = %vector.body1627, %vector.ph1622
  %index1628 = phi i64 [ 0, %vector.ph1622 ], [ %index.next1634, %vector.body1627 ]
  %vec.phi1629 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %325, %vector.body1627 ]
  %vec.phi1630 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %327, %vector.body1627 ]
  %vec.phi1631 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %329, %vector.body1627 ]
  %319 = add i64 %316, %index1628
  %320 = getelementptr inbounds float, float* %arrayptr317655, i64 %319
  %321 = bitcast float* %320 to <8 x float>*
  %wide.load1632 = load <8 x float>, <8 x float>* %321, align 4
  %322 = getelementptr inbounds float, float* %arrayptr320656, i64 %index1628
  %323 = bitcast float* %322 to <8 x float>*
  %wide.load1633 = load <8 x float>, <8 x float>* %323, align 4
  %324 = fmul contract <8 x float> %wide.load1632, %wide.load1632
  %325 = fadd reassoc contract <8 x float> %vec.phi1629, %324
  %326 = fmul contract <8 x float> %wide.load1632, %wide.load1633
  %327 = fadd reassoc contract <8 x float> %vec.phi1630, %326
  %328 = fmul contract <8 x float> %wide.load1633, %wide.load1633
  %329 = fadd reassoc contract <8 x float> %vec.phi1631, %328
  %index.next1634 = add nuw i64 %index1628, 8
  %330 = icmp eq i64 %index.next1634, %n.vec1624
  br i1 %330, label %middle.block1619, label %vector.body1627

middle.block1619:                                 ; preds = %vector.body1627
  %331 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %329)
  %332 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %327)
  %333 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %325)
  %cmp.n1626 = icmp eq i64 %arraylen533, %n.vec1624
  br i1 %cmp.n1626, label %L689, label %scalar.ph1620

scalar.ph1620:                                    ; preds = %middle.block1619, %L619.lr.ph
  %bc.resume.val1625 = phi i64 [ %n.vec1624, %middle.block1619 ], [ 0, %L619.lr.ph ]
  %bc.merge.rdx1635 = phi float [ %333, %middle.block1619 ], [ 0.000000e+00, %L619.lr.ph ]
  %bc.merge.rdx1636 = phi float [ %332, %middle.block1619 ], [ 0.000000e+00, %L619.lr.ph ]
  %bc.merge.rdx1637 = phi float [ %331, %middle.block1619 ], [ 0.000000e+00, %L619.lr.ph ]
  br label %L619

L619:                                             ; preds = %L619, %scalar.ph1620
  %value_phi312886 = phi float [ %bc.merge.rdx1635, %scalar.ph1620 ], [ %338, %L619 ]
  %value_phi311885 = phi i64 [ %bc.resume.val1625, %scalar.ph1620 ], [ %343, %L619 ]
  %value_phi310884 = phi float [ %bc.merge.rdx1636, %scalar.ph1620 ], [ %340, %L619 ]
  %value_phi309883 = phi float [ %bc.merge.rdx1637, %scalar.ph1620 ], [ %342, %L619 ]
  %334 = add i64 %316, %value_phi311885
  %335 = getelementptr inbounds float, float* %arrayptr317655, i64 %334
  %arrayref318 = load float, float* %335, align 4
  %336 = getelementptr inbounds float, float* %arrayptr320656, i64 %value_phi311885
  %arrayref321 = load float, float* %336, align 4
  %337 = fmul contract float %arrayref318, %arrayref318
  %338 = fadd reassoc contract float %value_phi312886, %337
  %339 = fmul contract float %arrayref318, %arrayref321
  %340 = fadd reassoc contract float %value_phi310884, %339
  %341 = fmul contract float %arrayref321, %arrayref321
  %342 = fadd reassoc contract float %value_phi309883, %341
  %343 = add nuw nsw i64 %value_phi311885, 1
  %exitcond1050.not = icmp eq i64 %343, %arraylen533
  br i1 %exitcond1050.not, label %L689, label %L619

L648:                                             ; preds = %idxend301
  br i1 %.not691, label %L689, label %L661.lr.ph

L661.lr.ph:                                       ; preds = %L648
  %344 = bitcast {}* %getfield291 to {}**
  %arraysize_ptr539 = getelementptr inbounds {}*, {}** %344, i64 3
  %345 = bitcast {}** %arraysize_ptr539 to i64*
  %arraysize540 = load i64, i64* %345, align 8
  %346 = mul i64 %arraysize540, %312
  %347 = bitcast {}* %getfield291 to float**
  %arrayptr543693 = load float*, float** %347, align 8
  %348 = bitcast {}* %getfield293 to float**
  %arrayptr546694 = load float*, float** %348, align 8
  %min.iters.check1598 = icmp ult i64 %arraylen533, 16
  br i1 %min.iters.check1598, label %scalar.ph1597, label %vector.ph1599

vector.ph1599:                                    ; preds = %L661.lr.ph
  %n.vec1601 = and i64 %arraylen533, 9223372036854775792
  br label %vector.body1604

vector.body1604:                                  ; preds = %vector.body1604, %vector.ph1599
  %index1605 = phi i64 [ 0, %vector.ph1599 ], [ %index.next1614, %vector.body1604 ]
  %vec.phi1606 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %360, %vector.body1604 ]
  %vec.phi1607 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %361, %vector.body1604 ]
  %vec.phi1608 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %364, %vector.body1604 ]
  %vec.phi1609 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %365, %vector.body1604 ]
  %349 = add i64 %346, %index1605
  %350 = getelementptr inbounds float, float* %arrayptr543693, i64 %349
  %351 = bitcast float* %350 to <8 x float>*
  %wide.load1610 = load <8 x float>, <8 x float>* %351, align 4
  %352 = getelementptr inbounds float, float* %350, i64 8
  %353 = bitcast float* %352 to <8 x float>*
  %wide.load1611 = load <8 x float>, <8 x float>* %353, align 4
  %354 = getelementptr inbounds float, float* %arrayptr546694, i64 %index1605
  %355 = bitcast float* %354 to <8 x float>*
  %wide.load1612 = load <8 x float>, <8 x float>* %355, align 4
  %356 = getelementptr inbounds float, float* %354, i64 8
  %357 = bitcast float* %356 to <8 x float>*
  %wide.load1613 = load <8 x float>, <8 x float>* %357, align 4
  %358 = fmul contract <8 x float> %wide.load1610, %wide.load1612
  %359 = fmul contract <8 x float> %wide.load1611, %wide.load1613
  %360 = fadd reassoc contract <8 x float> %vec.phi1606, %358
  %361 = fadd reassoc contract <8 x float> %vec.phi1607, %359
  %362 = fmul contract <8 x float> %wide.load1612, %wide.load1612
  %363 = fmul contract <8 x float> %wide.load1613, %wide.load1613
  %364 = fadd reassoc contract <8 x float> %vec.phi1608, %362
  %365 = fadd reassoc contract <8 x float> %vec.phi1609, %363
  %index.next1614 = add nuw i64 %index1605, 16
  %366 = icmp eq i64 %index.next1614, %n.vec1601
  br i1 %366, label %middle.block1596, label %vector.body1604

middle.block1596:                                 ; preds = %vector.body1604
  %bin.rdx1617 = fadd reassoc contract <8 x float> %365, %364
  %367 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1617)
  %bin.rdx1615 = fadd reassoc contract <8 x float> %361, %360
  %368 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1615)
  %cmp.n1603 = icmp eq i64 %arraylen533, %n.vec1601
  br i1 %cmp.n1603, label %L689, label %scalar.ph1597

scalar.ph1597:                                    ; preds = %middle.block1596, %L661.lr.ph
  %bc.resume.val1602 = phi i64 [ %n.vec1601, %middle.block1596 ], [ 0, %L661.lr.ph ]
  %bc.merge.rdx1616 = phi float [ %368, %middle.block1596 ], [ 0.000000e+00, %L661.lr.ph ]
  %bc.merge.rdx1618 = phi float [ %367, %middle.block1596 ], [ 0.000000e+00, %L661.lr.ph ]
  br label %L661

L661:                                             ; preds = %L661, %scalar.ph1597
  %value_phi538893 = phi i64 [ %bc.resume.val1602, %scalar.ph1597 ], [ %376, %L661 ]
  %value_phi537892 = phi float [ %bc.merge.rdx1616, %scalar.ph1597 ], [ %373, %L661 ]
  %value_phi536891 = phi float [ %bc.merge.rdx1618, %scalar.ph1597 ], [ %375, %L661 ]
  %369 = add i64 %346, %value_phi538893
  %370 = getelementptr inbounds float, float* %arrayptr543693, i64 %369
  %arrayref544 = load float, float* %370, align 4
  %371 = getelementptr inbounds float, float* %arrayptr546694, i64 %value_phi538893
  %arrayref547 = load float, float* %371, align 4
  %372 = fmul contract float %arrayref544, %arrayref547
  %373 = fadd reassoc contract float %value_phi537892, %372
  %374 = fmul contract float %arrayref547, %arrayref547
  %375 = fadd reassoc contract float %value_phi536891, %374
  %376 = add nuw nsw i64 %value_phi538893, 1
  %exitcond1051.not = icmp eq i64 %376, %arraylen533
  br i1 %exitcond1051.not, label %L689, label %L661

L689:                                             ; preds = %L661, %middle.block1596, %L648, %L619, %middle.block1619, %L605
  %value_phi329 = phi float [ 0.000000e+00, %L605 ], [ 0.000000e+00, %L648 ], [ %367, %middle.block1596 ], [ %331, %middle.block1619 ], [ %375, %L661 ], [ %342, %L619 ]
  %value_phi330 = phi float [ 0.000000e+00, %L605 ], [ 0.000000e+00, %L648 ], [ %368, %middle.block1596 ], [ %332, %middle.block1619 ], [ %373, %L661 ], [ %340, %L619 ]
  %value_phi331 = phi float [ 0.000000e+00, %L605 ], [ %arrayref304, %L648 ], [ %arrayref304, %middle.block1596 ], [ %333, %middle.block1619 ], [ %arrayref304, %L661 ], [ %338, %L619 ]
  %377 = fsub float %value_phi329, %value_phi329
  %378 = fcmp uno float %377, 0.000000e+00
  br i1 %378, label %L694, label %L696

L694:                                             ; preds = %L689
  %379 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield289, {}** %379, align 8
  %380 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield293, {}** %380, align 16
  call void @j__check_residual_1852({}* nonnull %getfield293, i64 signext %arrayref287)
  br label %L696

L696:                                             ; preds = %L694, %L689
  %381 = fcmp une float %value_phi331, 0.000000e+00
  br i1 %381, label %L737, label %L698

L698:                                             ; preds = %L696
  %getfield333 = load atomic {}*, {}** %308 unordered, align 8
  %382 = bitcast {}* %getfield333 to {}**
  %arraysize_ptr334 = getelementptr inbounds {}*, {}** %382, i64 3
  %383 = bitcast {}** %arraysize_ptr334 to i64*
  %arraysize335 = load i64, i64* %383, align 8
  %.not657.not = icmp eq i64 %arraysize335, 0
  br i1 %.not657.not, label %L737, label %L711.preheader

L711.preheader:                                   ; preds = %L698
  %arraysize_ptr349 = getelementptr inbounds {}*, {}** %382, i64 4
  %384 = bitcast {}** %arraysize_ptr349 to i64*
  %arraysize350 = load i64, i64* %384, align 8
  %inbounds351 = icmp ult i64 %312, %arraysize350
  %385 = mul i64 %arraysize335, %312
  %386 = bitcast {}* %getfield333 to float**
  %arrayptr356659 = load float*, float** %386, align 8
  %inbounds351.fr = freeze i1 %inbounds351
  br i1 %inbounds351.fr, label %ib347.us, label %oob352

ib347.us:                                         ; preds = %L717.us, %L711.preheader
  %value_phi340.us = phi i64 [ %391, %L717.us ], [ 1, %L711.preheader ]
  %387 = add nsw i64 %value_phi340.us, -1
  %388 = add i64 %385, %387
  %389 = getelementptr inbounds float, float* %arrayptr356659, i64 %388
  %arrayref357.us = load float, float* %389, align 4
  %390 = fcmp une float %arrayref357.us, 0.000000e+00
  br i1 %390, label %L733.split.us, label %L717.us

L717.us:                                          ; preds = %ib347.us
  %391 = add nuw nsw i64 %value_phi340.us, 1
  %392 = icmp ult i64 %value_phi340.us, %arraysize335
  br i1 %392, label %ib347.us, label %L737

L733.split.us:                                    ; preds = %ib347.us
  store {}* inttoptr (i64 135794572797712 to {}*), {}** %6, align 8
  %393 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %393)
  unreachable

L737:                                             ; preds = %L717.us, %L698, %L696
  %394 = fsub float %value_phi331, %value_phi331
  %395 = fcmp uno float %394, 0.000000e+00
  br i1 %395, label %L1052, label %L742

L742:                                             ; preds = %L737
  %getfield365 = load atomic {}*, {}** %295 unordered, align 8
  %396 = bitcast {}* %getfield365 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr367 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %396, i64 0, i32 1
  %arraylen368 = load i64, i64* %arraylen_ptr367, align 8
  %.not661 = icmp ult i64 %312, %arraylen368
  br i1 %.not661, label %L756, label %L753

L753:                                             ; preds = %L742
  store i64 %arrayref287, i64* %296, align 8
  %397 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield365, {}** %397, align 16
  call void @j_throw_boundserror_1847({}* nonnull %getfield365, [1 x i64]* nocapture readonly %newstruct366) #2
  unreachable

L756:                                             ; preds = %L742
  %398 = bitcast {}* %getfield365 to i64**
  %arrayptr373662 = load i64*, i64** %398, align 8
  %399 = getelementptr inbounds i64, i64* %arrayptr373662, i64 %312
  %arrayref374 = load i64, i64* %399, align 8
  %.not663 = icmp eq i64 %arrayref374, 0
  br i1 %.not663, label %L766, label %L761

L761:                                             ; preds = %L756
  %400 = bitcast {}* %0 to float***
  %getfield5241813 = load atomic float**, float*** %400 unordered, align 8
  %401 = add i64 %arrayref374, -1
  %arrayptr526690 = load float*, float** %getfield5241813, align 8
  %402 = getelementptr inbounds float, float* %arrayptr526690, i64 %401
  %arrayref527 = load float, float* %402, align 4
  br label %L766

L766:                                             ; preds = %L761, %L756
  %value_phi375 = phi float [ %arrayref527, %L761 ], [ 0.000000e+00, %L756 ]
  br i1 %381, label %L770, label %L768

L768:                                             ; preds = %L766
  %403 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield289, {}** %403, align 8
  %404 = call float @j__coordinate_minimizer_1845({ double }* nocapture nonnull readonly %2, float %value_phi375, i64 signext %arrayref287)
  br label %L970

L770:                                             ; preds = %L766
  %getfield465 = load atomic {}*, {}** %293 unordered, align 8
  %405 = bitcast {}* %getfield465 to i8*
  %getfield_addr466 = getelementptr inbounds i8, i8* %405, i64 24
  %406 = bitcast i8* %getfield_addr466 to {}**
  %getfield467 = load atomic {}*, {}** %406 unordered, align 8
  %407 = bitcast {}* %getfield467 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr468 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %407, i64 0, i32 1
  %arraylen469 = load i64, i64* %arraylen_ptr468, align 8
  %408 = sitofp i64 %arraylen469 to float
  %409 = fmul float %408, 0x3980000000000000
  %410 = fcmp ole float %409, %value_phi331
  %411 = fcmp ord float %377, 0.000000e+00
  %412 = fcmp ole float %409, %value_phi329
  %413 = and i1 %411, %412
  %414 = and i1 %410, %413
  br i1 %414, label %L789, label %L967

L789:                                             ; preds = %L770
  %aggregate_load_box470.sroa.0.0.copyload = load float, float* %aggregate_load_box470.sroa.0.0..sroa_idx, align 1
  %415 = fcmp uge float %value_phi331, 0.000000e+00
  br i1 %415, label %L795, label %L793

L793:                                             ; preds = %L789
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %value_phi331) #2
  unreachable

L795:                                             ; preds = %L789
  %416 = call float @llvm.sqrt.f32(float %value_phi331)
  %417 = fcmp ugt float %416, %aggregate_load_box470.sroa.0.0.copyload
  br i1 %417, label %L800, label %L970

L800:                                             ; preds = %L795
  %418 = fdiv float %value_phi330, %value_phi331
  %419 = fadd float %418, %value_phi375
  %420 = fmul float %value_phi330, %418
  %421 = fsub float %value_phi329, %420
  %422 = fmul float %value_phi329, 6.250000e-02
  %423 = fcmp uge float %421, %422
  br i1 %423, label %L855, label %L807

L807:                                             ; preds = %L800
  %.not680 = icmp eq i64 %arraylen469, 0
  br i1 %.not680, label %L844, label %L821.lr.ph

L821.lr.ph:                                       ; preds = %L807
  %424 = bitcast {}* %getfield465 to {}**
  %getfield475 = load atomic {}*, {}** %424 unordered, align 8
  %425 = bitcast {}* %getfield467 to float**
  %arrayptr485682 = load float*, float** %425, align 8
  %426 = bitcast {}* %getfield475 to {}**
  %arraysize_ptr487 = getelementptr inbounds {}*, {}** %426, i64 3
  %427 = bitcast {}** %arraysize_ptr487 to i64*
  %arraysize488 = load i64, i64* %427, align 8
  %428 = mul i64 %arraysize488, %312
  %429 = bitcast {}* %getfield475 to float**
  %arrayptr491683 = load float*, float** %429, align 8
  %min.iters.check1575 = icmp ult i64 %arraylen469, 16
  br i1 %min.iters.check1575, label %scalar.ph1574, label %vector.ph1576

vector.ph1576:                                    ; preds = %L821.lr.ph
  %n.vec1578 = and i64 %arraylen469, 9223372036854775792
  %broadcast.splatinsert1589 = insertelement <8 x float> poison, float %418, i64 0
  %broadcast.splat1590 = shufflevector <8 x float> %broadcast.splatinsert1589, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1581

vector.body1581:                                  ; preds = %vector.body1581, %vector.ph1576
  %index1582 = phi i64 [ 0, %vector.ph1576 ], [ %index.next1593, %vector.body1581 ]
  %vec.phi1583 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1576 ], [ %445, %vector.body1581 ]
  %vec.phi1584 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1576 ], [ %446, %vector.body1581 ]
  %430 = getelementptr inbounds float, float* %arrayptr485682, i64 %index1582
  %431 = bitcast float* %430 to <8 x float>*
  %wide.load1585 = load <8 x float>, <8 x float>* %431, align 4
  %432 = getelementptr inbounds float, float* %430, i64 8
  %433 = bitcast float* %432 to <8 x float>*
  %wide.load1586 = load <8 x float>, <8 x float>* %433, align 4
  %434 = add i64 %428, %index1582
  %435 = getelementptr inbounds float, float* %arrayptr491683, i64 %434
  %436 = bitcast float* %435 to <8 x float>*
  %wide.load1587 = load <8 x float>, <8 x float>* %436, align 4
  %437 = getelementptr inbounds float, float* %435, i64 8
  %438 = bitcast float* %437 to <8 x float>*
  %wide.load1588 = load <8 x float>, <8 x float>* %438, align 4
  %439 = fmul <8 x float> %broadcast.splat1590, %wide.load1587
  %440 = fmul <8 x float> %broadcast.splat1590, %wide.load1588
  %441 = fsub <8 x float> %wide.load1585, %439
  %442 = fsub <8 x float> %wide.load1586, %440
  %443 = fmul contract <8 x float> %441, %441
  %444 = fmul contract <8 x float> %442, %442
  %445 = fadd reassoc contract <8 x float> %vec.phi1583, %443
  %446 = fadd reassoc contract <8 x float> %vec.phi1584, %444
  %index.next1593 = add nuw i64 %index1582, 16
  %447 = icmp eq i64 %index.next1593, %n.vec1578
  br i1 %447, label %middle.block1573, label %vector.body1581

middle.block1573:                                 ; preds = %vector.body1581
  %bin.rdx1594 = fadd reassoc contract <8 x float> %446, %445
  %448 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1594)
  %cmp.n1580 = icmp eq i64 %arraylen469, %n.vec1578
  br i1 %cmp.n1580, label %L844, label %scalar.ph1574

scalar.ph1574:                                    ; preds = %middle.block1573, %L821.lr.ph
  %bc.resume.val1579 = phi i64 [ %n.vec1578, %middle.block1573 ], [ 0, %L821.lr.ph ]
  %bc.merge.rdx1595 = phi float [ %448, %middle.block1573 ], [ 0.000000e+00, %L821.lr.ph ]
  br label %L821

L821:                                             ; preds = %L821, %scalar.ph1574
  %value_phi483898 = phi i64 [ %bc.resume.val1579, %scalar.ph1574 ], [ %456, %L821 ]
  %value_phi482897 = phi float [ %bc.merge.rdx1595, %scalar.ph1574 ], [ %455, %L821 ]
  %449 = getelementptr inbounds float, float* %arrayptr485682, i64 %value_phi483898
  %arrayref486 = load float, float* %449, align 4
  %450 = add i64 %428, %value_phi483898
  %451 = getelementptr inbounds float, float* %arrayptr491683, i64 %450
  %arrayref492 = load float, float* %451, align 4
  %452 = fmul float %418, %arrayref492
  %453 = fsub float %arrayref486, %452
  %454 = fmul contract float %453, %453
  %455 = fadd reassoc contract float %value_phi482897, %454
  %456 = add nuw nsw i64 %value_phi483898, 1
  %exitcond1052.not = icmp eq i64 %456, %arraylen469
  br i1 %exitcond1052.not, label %L844, label %L821

L844:                                             ; preds = %L821, %middle.block1573, %L807
  %value_phi494 = phi float [ 0.000000e+00, %L807 ], [ %448, %middle.block1573 ], [ %455, %L821 ]
  %457 = fsub float %value_phi494, %value_phi494
  %458 = fcmp uno float %457, 0.000000e+00
  %459 = fcmp ugt float %409, %value_phi494
  %460 = or i1 %459, %458
  br i1 %460, label %L853, label %L855

L853:                                             ; preds = %L844
  %461 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield289, {}** %461, align 8
  %462 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi375, i64 signext %arrayref287)
  br label %L970

L855:                                             ; preds = %L844, %L800
  %value_phi496 = phi float [ %421, %L800 ], [ %value_phi494, %L844 ]
  %463 = fcmp uge float %value_phi496, 0.000000e+00
  br i1 %463, label %L860, label %L858

L858:                                             ; preds = %L855
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %value_phi496) #2
  unreachable

L860:                                             ; preds = %L855
  %464 = call float @llvm.sqrt.f32(float %value_phi496)
  %465 = fsub float %416, %aggregate_load_box470.sroa.0.0.copyload
  %466 = fcmp uge float %465, 0.000000e+00
  br i1 %466, label %L867, label %L865

L865:                                             ; preds = %L860
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %465) #2
  unreachable

L867:                                             ; preds = %L860
  %467 = fadd float %416, %aggregate_load_box470.sroa.0.0.copyload
  %468 = fcmp uge float %467, 0.000000e+00
  br i1 %468, label %L874, label %L872

L872:                                             ; preds = %L867
  call void @j_throw_complex_domainerror_1848({}* inttoptr (i64 135794596555280 to {}*), float %467) #2
  unreachable

L874:                                             ; preds = %L867
  %469 = call float @llvm.sqrt.f32(float %465)
  %470 = call float @llvm.sqrt.f32(float %467)
  %471 = fmul float %469, %470
  %472 = fmul float %416, %471
  %473 = fdiv float %464, %472
  %474 = fmul float %aggregate_load_box470.sroa.0.0.copyload, %473
  %475 = fcmp oge float %472, 0x3810000000000000
  %476 = fcmp oge float %473, 0x3810000000000000
  %477 = fcmp ole float %473, 0x47EFFFFFE0000000
  %narrow684 = and i1 %476, %477
  %478 = and i1 %475, %narrow684
  %479 = fcmp oge float %474, 0x3810000000000000
  %480 = fcmp ole float %474, 0x47EFFFFFE0000000
  %narrow685 = and i1 %479, %480
  %481 = and i1 %478, %narrow685
  br i1 %481, label %L908, label %L965

L908:                                             ; preds = %L874
  %482 = fneg float %474
  %.inv687 = fcmp ogt float %419, %482
  %483 = select i1 %.inv687, float %419, float %482
  %.inv688 = fcmp olt float %483, %474
  %484 = select i1 %.inv688, float %483, float %474
  %485 = fsub float %419, %484
  %486 = fadd float %485, 0.000000e+00
  br label %L970

L965:                                             ; preds = %L874
  %487 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield289, {}** %487, align 8
  %488 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi375, i64 signext %arrayref287)
  br label %L970

L967:                                             ; preds = %L770
  %489 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield289, {}** %489, align 8
  %490 = call float @j__sqrt_offrange_step_1850({}* nonnull %1, float %value_phi375, i64 signext %arrayref287)
  br label %L970

L970:                                             ; preds = %L967, %L965, %L908, %L853, %L795, %L768
  %value_phi376 = phi float [ %404, %L768 ], [ %462, %L853 ], [ %488, %L965 ], [ %490, %L967 ], [ 0.000000e+00, %L795 ], [ %486, %L908 ]
  %getfield378 = load atomic {}*, {}** %311 unordered, align 8
  %491 = bitcast {}* %getfield378 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr379 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %491, i64 0, i32 1
  %arraylen380 = load i64, i64* %arraylen_ptr379, align 8
  %inbounds381 = icmp ult i64 %312, %arraylen380
  br i1 %inbounds381, label %idxend384, label %oob382

L978:                                             ; preds = %idxend384
  %getfield398 = load atomic {}*, {}** %295 unordered, align 8
  %492 = bitcast {}* %getfield398 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr400 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %492, i64 0, i32 1
  %arraylen401 = load i64, i64* %arraylen_ptr400, align 8
  %.not668 = icmp ult i64 %312, %arraylen401
  br i1 %.not668, label %L992, label %L989

L989:                                             ; preds = %L978
  store i64 %arrayref287, i64* %300, align 8
  %493 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield398, {}** %493, align 16
  call void @j_throw_boundserror_1847({}* nonnull %getfield398, [1 x i64]* nocapture readonly %newstruct399) #2
  unreachable

L992:                                             ; preds = %L978
  %494 = bitcast {}* %getfield398 to i64**
  %arrayptr406669 = load i64*, i64** %494, align 8
  %495 = getelementptr inbounds i64, i64* %arrayptr406669, i64 %312
  %arrayref407 = load i64, i64* %495, align 8
  %.not670 = icmp eq i64 %arrayref407, 0
  br i1 %.not670, label %L1000, label %L997

L997:                                             ; preds = %L992
  %496 = bitcast {}* %0 to float***
  %getfield4091814 = load atomic float**, float*** %496 unordered, align 8
  %497 = add i64 %arrayref407, -1
  %arrayptr411671 = load float*, float** %getfield4091814, align 8
  %498 = getelementptr inbounds float, float* %arrayptr411671, i64 %497
  store float %value_phi376, float* %498, align 4
  br label %L1017

L1000:                                            ; preds = %L992
  %499 = fcmp oeq float %value_phi376, 0.000000e+00
  br i1 %499, label %L1017, label %L1003

L1003:                                            ; preds = %L1000
  %500 = load i64, i64* %302, align 8
  %501 = add i64 %500, 1
  store i64 %501, i64* %302, align 8
  %getfield434 = load atomic {}*, {}** %297 unordered, align 8
  %502 = bitcast {}* %getfield434 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr435 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %502, i64 0, i32 1
  %arraylen436 = load i64, i64* %arraylen_ptr435, align 8
  %inbounds437 = icmp ult i64 %500, %arraylen436
  br i1 %inbounds437, label %idxend440, label %oob438

L1017:                                            ; preds = %idxend460, %L1000, %L997
  %getfield413 = load atomic {}*, {}** %310 unordered, align 8
  %503 = bitcast {}* %getfield413 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr416 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %503, i64 0, i32 1
  %arraylen417 = load i64, i64* %arraylen_ptr416, align 8
  %.not672 = icmp eq i64 %arraylen417, 0
  br i1 %.not672, label %L1054, label %L1030.lr.ph

L1030.lr.ph:                                      ; preds = %L1017
  %getfield415 = load atomic {}*, {}** %308 unordered, align 8
  %504 = bitcast {}* %getfield413 to float**
  %arrayptr422674 = load float*, float** %504, align 8
  %505 = bitcast {}* %getfield415 to {}**
  %arraysize_ptr424 = getelementptr inbounds {}*, {}** %505, i64 3
  %506 = bitcast {}** %arraysize_ptr424 to i64*
  %arraysize425 = load i64, i64* %506, align 8
  %507 = mul i64 %arraysize425, %312
  %508 = bitcast {}* %getfield415 to float**
  %arrayptr428675 = load float*, float** %508, align 8
  %min.iters.check1548 = icmp ult i64 %arraylen417, 32
  br i1 %min.iters.check1548, label %scalar.ph1547, label %vector.memcheck1535

vector.memcheck1535:                              ; preds = %L1030.lr.ph
  %scevgep1537 = getelementptr float, float* %arrayptr422674, i64 %arraylen417
  %scevgep1539 = getelementptr float, float* %arrayptr428675, i64 %507
  %509 = add i64 %arraylen417, %507
  %scevgep1541 = getelementptr float, float* %arrayptr428675, i64 %509
  %bound01543 = icmp ult float* %arrayptr422674, %scevgep1541
  %bound11544 = icmp ult float* %scevgep1539, %scevgep1537
  %found.conflict1545 = and i1 %bound01543, %bound11544
  br i1 %found.conflict1545, label %scalar.ph1547, label %vector.ph1549

vector.ph1549:                                    ; preds = %vector.memcheck1535
  %n.vec1551 = and i64 %arraylen417, 9223372036854775776
  %broadcast.splatinsert1564 = insertelement <8 x float> poison, float %575, i64 0
  %broadcast.splat1565 = shufflevector <8 x float> %broadcast.splatinsert1564, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1554

vector.body1554:                                  ; preds = %vector.body1554, %vector.ph1549
  %index1555 = phi i64 [ 0, %vector.ph1549 ], [ %index.next1572, %vector.body1554 ]
  %510 = getelementptr inbounds float, float* %arrayptr422674, i64 %index1555
  %511 = bitcast float* %510 to <8 x float>*
  %wide.load1556 = load <8 x float>, <8 x float>* %511, align 4
  %512 = getelementptr inbounds float, float* %510, i64 8
  %513 = bitcast float* %512 to <8 x float>*
  %wide.load1557 = load <8 x float>, <8 x float>* %513, align 4
  %514 = getelementptr inbounds float, float* %510, i64 16
  %515 = bitcast float* %514 to <8 x float>*
  %wide.load1558 = load <8 x float>, <8 x float>* %515, align 4
  %516 = getelementptr inbounds float, float* %510, i64 24
  %517 = bitcast float* %516 to <8 x float>*
  %wide.load1559 = load <8 x float>, <8 x float>* %517, align 4
  %518 = add i64 %507, %index1555
  %519 = getelementptr inbounds float, float* %arrayptr428675, i64 %518
  %520 = bitcast float* %519 to <8 x float>*
  %wide.load1560 = load <8 x float>, <8 x float>* %520, align 4
  %521 = getelementptr inbounds float, float* %519, i64 8
  %522 = bitcast float* %521 to <8 x float>*
  %wide.load1561 = load <8 x float>, <8 x float>* %522, align 4
  %523 = getelementptr inbounds float, float* %519, i64 16
  %524 = bitcast float* %523 to <8 x float>*
  %wide.load1562 = load <8 x float>, <8 x float>* %524, align 4
  %525 = getelementptr inbounds float, float* %519, i64 24
  %526 = bitcast float* %525 to <8 x float>*
  %wide.load1563 = load <8 x float>, <8 x float>* %526, align 4
  %527 = fmul <8 x float> %broadcast.splat1565, %wide.load1560
  %528 = fmul <8 x float> %broadcast.splat1565, %wide.load1561
  %529 = fmul <8 x float> %broadcast.splat1565, %wide.load1562
  %530 = fmul <8 x float> %broadcast.splat1565, %wide.load1563
  %531 = fsub <8 x float> %wide.load1556, %527
  %532 = fsub <8 x float> %wide.load1557, %528
  %533 = fsub <8 x float> %wide.load1558, %529
  %534 = fsub <8 x float> %wide.load1559, %530
  store <8 x float> %531, <8 x float>* %511, align 4
  store <8 x float> %532, <8 x float>* %513, align 4
  store <8 x float> %533, <8 x float>* %515, align 4
  store <8 x float> %534, <8 x float>* %517, align 4
  %index.next1572 = add nuw i64 %index1555, 32
  %535 = icmp eq i64 %index.next1572, %n.vec1551
  br i1 %535, label %middle.block1546, label %vector.body1554

middle.block1546:                                 ; preds = %vector.body1554
  %cmp.n1553 = icmp eq i64 %arraylen417, %n.vec1551
  br i1 %cmp.n1553, label %L1054, label %scalar.ph1547

scalar.ph1547:                                    ; preds = %middle.block1546, %vector.memcheck1535, %L1030.lr.ph
  %bc.resume.val1552 = phi i64 [ %n.vec1551, %middle.block1546 ], [ 0, %L1030.lr.ph ], [ 0, %vector.memcheck1535 ]
  br label %L1030

L1030:                                            ; preds = %L1030, %scalar.ph1547
  %value_phi420901 = phi i64 [ %bc.resume.val1552, %scalar.ph1547 ], [ %541, %L1030 ]
  %536 = getelementptr inbounds float, float* %arrayptr422674, i64 %value_phi420901
  %arrayref423 = load float, float* %536, align 4
  %537 = add i64 %507, %value_phi420901
  %538 = getelementptr inbounds float, float* %arrayptr428675, i64 %537
  %arrayref429 = load float, float* %538, align 4
  %539 = fmul float %575, %arrayref429
  %540 = fsub float %arrayref423, %539
  store float %540, float* %536, align 4
  %541 = add nuw nsw i64 %value_phi420901, 1
  %exitcond1053.not = icmp eq i64 %541, %arraylen417
  br i1 %exitcond1053.not, label %L1054, label %L1030

L1052:                                            ; preds = %L737
  call void @j__refuse_curvature_1851(i64 signext %arrayref287) #2
  unreachable

L1054:                                            ; preds = %idxend384, %L1030, %middle.block1546, %L1017
  %arrayref2871005 = phi i64 [ %arrayref287, %L1017 ], [ %arrayref2871006, %idxend384 ], [ %arrayref287, %middle.block1546 ], [ %arrayref287, %L1030 ]
  %542 = call float @llvm.fabs.f32(float %575)
  %543 = fcmp oeq float %575, 0.000000e+00
  %or.cond1302 = select i1 %.not665, i1 true, i1 %543
  br i1 %or.cond1302, label %L1065, label %L1060

L1060:                                            ; preds = %L1054
  %getfield389 = load atomic {}*, {}** %293 unordered, align 8
  %544 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield389, {}** %544, align 16
  %545 = call float @j_coordinate_scale_1846({}* nonnull %getfield389, {}* nonnull %0, i64 signext %arrayref287)
  %546 = fmul float %542, %545
  br label %L1065

L1065:                                            ; preds = %L1060, %L1054
  %value_phi390 = phi float [ %546, %L1060 ], [ %542, %L1054 ]
  %547 = fsub float %value_phi390, %value_phi390
  %548 = fcmp uno float %547, 0.000000e+00
  br i1 %548, label %L1071, label %L1074

L1071:                                            ; preds = %L1065
  store {}* inttoptr (i64 135794568852048 to {}*), {}** %6, align 8
  %549 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %549)
  unreachable

L1074:                                            ; preds = %L1065
  %.inv666 = fcmp olt float %value_phi277, %value_phi390
  %550 = select i1 %.inv666, float %value_phi390, float %value_phi277
  %.not667.not = icmp eq i64 %value_phi275, %18
  %551 = add nuw i64 %value_phi275, 1
  br i1 %.not667.not, label %L1089.loopexit, label %L569

L1089.loopexit:                                   ; preds = %L1074
  store i64 %arrayref287, i64* %296, align 8
  store i64 %arrayref2871005, i64* %300, align 8
  br label %L1089

L1089.loopexit699:                                ; preds = %L536
  store i64 %arrayref16, i64* %31, align 8
  store i64 %arrayref16944, i64* %35, align 8
  br label %L1089

L1089:                                            ; preds = %L1089.loopexit699, %L1089.loopexit, %L553, %L12
  %value_phi113 = phi float [ 0.000000e+00, %L12 ], [ 0.000000e+00, %L553 ], [ %550, %L1089.loopexit ], [ %289, %L1089.loopexit699 ]
  %552 = load {}*, {}** %10, align 8
  %553 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %552, {}** %553, align 8
  ret float %value_phi113

oob:                                              ; preds = %L30
  %errorbox = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield24, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L30
  %554 = bitcast {}* %getfield24 to float**
  %arrayptr26608 = load float*, float** %554, align 8
  %555 = getelementptr inbounds float, float* %arrayptr26608, i64 %49
  %arrayref27 = load float, float* %555, align 4
  %556 = fcmp ord float %arrayref27, 0.000000e+00
  %557 = bitcast {}* %getfield22 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr249 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %557, i64 0, i32 1
  %arraylen250 = load i64, i64* %arraylen_ptr249, align 8
  %.not645 = icmp eq i64 %arraylen250, 0
  br i1 %556, label %L110, label %L67

oob70:                                            ; preds = %L173.preheader
  %errorbox71614 = alloca [2 x i64], align 8
  %errorbox71614.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 0
  store i64 1, i64* %errorbox71614.sub, align 8
  %558 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 1
  store i64 %arrayref16, i64* %558, align 8
  call void @ijl_bounds_error_ints({}* %getfield52, i64* nonnull %errorbox71614.sub, i64 2)
  unreachable

oob99:                                            ; preds = %L432
  %errorbox100 = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox100, align 8
  call void @ijl_bounds_error_ints({}* %getfield95, i64* nonnull %errorbox100, i64 1)
  unreachable

idxend101:                                        ; preds = %L432
  %559 = bitcast {}* %getfield95 to float**
  %arrayptr103620 = load float*, float** %559, align 8
  %560 = getelementptr inbounds float, float* %arrayptr103620, i64 %49
  store float %value_phi50, float* %560, align 4
  %561 = fsub float %value_phi93, %value_phi92
  %562 = fcmp une float %561, 0.000000e+00
  br i1 %562, label %L440, label %L516

oob157:                                           ; preds = %L465
  %errorbox158 = alloca i64, align 8
  store i64 %240, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend159:                                        ; preds = %L465
  %563 = bitcast {}* %getfield153 to float**
  %arrayptr161632 = load float*, float** %563, align 8
  %564 = getelementptr inbounds float, float* %arrayptr161632, i64 %239
  store float %value_phi93, float* %564, align 4
  %getfield163 = load atomic {}*, {}** %38 unordered, align 8
  %565 = bitcast {}* %getfield163 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr164 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %565, i64 0, i32 1
  %arraylen165 = load i64, i64* %arraylen_ptr164, align 8
  %inbounds166 = icmp ult i64 %239, %arraylen165
  br i1 %inbounds166, label %idxend179, label %oob167

oob167:                                           ; preds = %idxend159
  %errorbox168 = alloca i64, align 8
  store i64 %240, i64* %errorbox168, align 8
  call void @ijl_bounds_error_ints({}* %getfield163, i64* nonnull %errorbox168, i64 1)
  unreachable

idxend179:                                        ; preds = %idxend159
  %566 = bitcast {}* %getfield163 to i64**
  %arrayptr171633 = load i64*, i64** %566, align 8
  %567 = getelementptr inbounds i64, i64* %arrayptr171633, i64 %239
  store i64 %arrayref16, i64* %567, align 8
  store i64 %240, i64* %234, align 8
  br label %L479

oob299:                                           ; preds = %L569
  %errorbox300 = alloca i64, align 8
  store i64 %arrayref287, i64* %errorbox300, align 8
  call void @ijl_bounds_error_ints({}* %getfield295, i64* nonnull %errorbox300, i64 1)
  unreachable

idxend301:                                        ; preds = %L569
  %568 = bitcast {}* %getfield295 to float**
  %arrayptr303652 = load float*, float** %568, align 8
  %569 = getelementptr inbounds float, float* %arrayptr303652, i64 %312
  %arrayref304 = load float, float* %569, align 4
  %570 = fcmp ord float %arrayref304, 0.000000e+00
  %571 = bitcast {}* %getfield293 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr532 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %571, i64 0, i32 1
  %arraylen533 = load i64, i64* %arraylen_ptr532, align 8
  %.not691 = icmp eq i64 %arraylen533, 0
  br i1 %570, label %L648, label %L605

oob352:                                           ; preds = %L711.preheader
  %errorbox353658 = alloca [2 x i64], align 8
  %errorbox353658.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox353658, i64 0, i64 0
  store i64 1, i64* %errorbox353658.sub, align 8
  %572 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox353658, i64 0, i64 1
  store i64 %arrayref287, i64* %572, align 8
  call void @ijl_bounds_error_ints({}* %getfield333, i64* nonnull %errorbox353658.sub, i64 2)
  unreachable

oob382:                                           ; preds = %L970
  %errorbox383 = alloca i64, align 8
  store i64 %arrayref287, i64* %errorbox383, align 8
  call void @ijl_bounds_error_ints({}* %getfield378, i64* nonnull %errorbox383, i64 1)
  unreachable

idxend384:                                        ; preds = %L970
  %573 = bitcast {}* %getfield378 to float**
  %arrayptr386664 = load float*, float** %573, align 8
  %574 = getelementptr inbounds float, float* %arrayptr386664, i64 %312
  store float %value_phi331, float* %574, align 4
  %575 = fsub float %value_phi376, %value_phi375
  %576 = fcmp une float %575, 0.000000e+00
  br i1 %576, label %L978, label %L1054

oob438:                                           ; preds = %L1003
  %errorbox439 = alloca i64, align 8
  store i64 %501, i64* %errorbox439, align 8
  call void @ijl_bounds_error_ints({}* %getfield434, i64* nonnull %errorbox439, i64 1)
  unreachable

idxend440:                                        ; preds = %L1003
  %577 = bitcast {}* %getfield434 to float**
  %arrayptr442677 = load float*, float** %577, align 8
  %578 = getelementptr inbounds float, float* %arrayptr442677, i64 %500
  store float %value_phi376, float* %578, align 4
  %getfield444 = load atomic {}*, {}** %303 unordered, align 8
  %579 = bitcast {}* %getfield444 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr445 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %579, i64 0, i32 1
  %arraylen446 = load i64, i64* %arraylen_ptr445, align 8
  %inbounds447 = icmp ult i64 %500, %arraylen446
  br i1 %inbounds447, label %idxend460, label %oob448

oob448:                                           ; preds = %idxend440
  %errorbox449 = alloca i64, align 8
  store i64 %501, i64* %errorbox449, align 8
  call void @ijl_bounds_error_ints({}* %getfield444, i64* nonnull %errorbox449, i64 1)
  unreachable

idxend460:                                        ; preds = %idxend440
  %580 = bitcast {}* %getfield444 to i64**
  %arrayptr452678 = load i64*, i64** %580, align 8
  %581 = getelementptr inbounds i64, i64* %arrayptr452678, i64 %500
  store i64 %arrayref287, i64* %581, align 8
  store i64 %501, i64* %495, align 8
  br label %L1017
}
