define float @"julia__sweep!_1580"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(72) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(48) %3, i8 zeroext %4, [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* nocapture noundef nonnull readonly align 8 dereferenceable(40) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1808 = alloca [5 x {}*], align 16
  %gcframe1808.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1808 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct83 = alloca [1 x i64], align 8
  %newstruct118 = alloca [1 x i64], align 8
  %newstruct367 = alloca [1 x i64], align 8
  %newstruct400 = alloca [1 x i64], align 8
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
  br i1 %.not, label %L554, label %L12

L12:                                              ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %19, i64 8
  %22 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %22 unordered, align 8
  %23 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield, {}** %23, align 16
  %24 = call nonnull {}* @"j__shuffle!_1582"({}* nonnull %getfield, i64 signext %18)
  %.not604 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not604, label %L1091, label %L30.preheader

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

L30:                                              ; preds = %L537, %L30.preheader
  %arrayref16945 = phi i64 [ %arrayref16944, %L537 ], [ undef, %L30.preheader ]
  %value_phi5 = phi i64 [ %291, %L537 ], [ 1, %L30.preheader ]
  %value_phi7 = phi float [ %290, %L537 ], [ 0.000000e+00, %L30.preheader ]
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
  %min.iters.check1518 = icmp ult i64 %arraylen251, 8
  br i1 %min.iters.check1518, label %scalar.ph1517, label %vector.ph1519

vector.ph1519:                                    ; preds = %L81.lr.ph
  %n.vec1521 = and i64 %arraylen251, 9223372036854775800
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
  %cmp.n1523 = icmp eq i64 %arraylen251, %n.vec1521
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
  %exitcond.not = icmp eq i64 %80, %arraylen251
  br i1 %exitcond.not, label %L151, label %L81

L110:                                             ; preds = %idxend
  br i1 %.not645, label %L151, label %L123.lr.ph

L123.lr.ph:                                       ; preds = %L110
  %81 = bitcast {}* %getfield20 to {}**
  %arraysize_ptr257 = getelementptr inbounds {}*, {}** %81, i64 3
  %82 = bitcast {}** %arraysize_ptr257 to i64*
  %arraysize258 = load i64, i64* %82, align 8
  %83 = mul i64 %arraysize258, %49
  %84 = bitcast {}* %getfield20 to float**
  %arrayptr261647 = load float*, float** %84, align 8
  %85 = bitcast {}* %getfield22 to float**
  %arrayptr264648 = load float*, float** %85, align 8
  %min.iters.check1495 = icmp ult i64 %arraylen251, 16
  br i1 %min.iters.check1495, label %scalar.ph1494, label %vector.ph1496

vector.ph1496:                                    ; preds = %L123.lr.ph
  %n.vec1498 = and i64 %arraylen251, 9223372036854775792
  br label %vector.body1501

vector.body1501:                                  ; preds = %vector.body1501, %vector.ph1496
  %index1502 = phi i64 [ 0, %vector.ph1496 ], [ %index.next1511, %vector.body1501 ]
  %vec.phi1503 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %97, %vector.body1501 ]
  %vec.phi1504 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %98, %vector.body1501 ]
  %vec.phi1505 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %101, %vector.body1501 ]
  %vec.phi1506 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1496 ], [ %102, %vector.body1501 ]
  %86 = add i64 %83, %index1502
  %87 = getelementptr inbounds float, float* %arrayptr261647, i64 %86
  %88 = bitcast float* %87 to <8 x float>*
  %wide.load1507 = load <8 x float>, <8 x float>* %88, align 4
  %89 = getelementptr inbounds float, float* %87, i64 8
  %90 = bitcast float* %89 to <8 x float>*
  %wide.load1508 = load <8 x float>, <8 x float>* %90, align 4
  %91 = getelementptr inbounds float, float* %arrayptr264648, i64 %index1502
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
  %cmp.n1500 = icmp eq i64 %arraylen251, %n.vec1498
  br i1 %cmp.n1500, label %L151, label %scalar.ph1494

scalar.ph1494:                                    ; preds = %middle.block1493, %L123.lr.ph
  %bc.resume.val1499 = phi i64 [ %n.vec1498, %middle.block1493 ], [ 0, %L123.lr.ph ]
  %bc.merge.rdx1513 = phi float [ %105, %middle.block1493 ], [ 0.000000e+00, %L123.lr.ph ]
  %bc.merge.rdx1515 = phi float [ %104, %middle.block1493 ], [ 0.000000e+00, %L123.lr.ph ]
  br label %L123

L123:                                             ; preds = %L123, %scalar.ph1494
  %value_phi256873 = phi i64 [ %bc.resume.val1499, %scalar.ph1494 ], [ %113, %L123 ]
  %value_phi255872 = phi float [ %bc.merge.rdx1513, %scalar.ph1494 ], [ %110, %L123 ]
  %value_phi254871 = phi float [ %bc.merge.rdx1515, %scalar.ph1494 ], [ %112, %L123 ]
  %106 = add i64 %83, %value_phi256873
  %107 = getelementptr inbounds float, float* %arrayptr261647, i64 %106
  %arrayref262 = load float, float* %107, align 4
  %108 = getelementptr inbounds float, float* %arrayptr264648, i64 %value_phi256873
  %arrayref265 = load float, float* %108, align 4
  %109 = fmul contract float %arrayref262, %arrayref265
  %110 = fadd reassoc contract float %value_phi255872, %109
  %111 = fmul contract float %arrayref265, %arrayref265
  %112 = fadd reassoc contract float %value_phi254871, %111
  %113 = add nuw nsw i64 %value_phi256873, 1
  %exitcond1047.not = icmp eq i64 %113, %arraylen251
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
  call void @j__check_residual_1592({}* nonnull %getfield22, i64 signext %arrayref16)
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
  store {}* inttoptr (i64 135794568225424 to {}*), {}** %6, align 8
  %130 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %130)
  unreachable

L199:                                             ; preds = %L179.us, %L160, %L158
  %131 = fsub float %value_phi50, %value_phi50
  %132 = fcmp uno float %131, 0.000000e+00
  br i1 %132, label %L515, label %L204

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
  call void @j_throw_boundserror_1586({}* nonnull %getfield82, [1 x i64]* nocapture readonly %newstruct83) #2
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
  %getfield2421810 = load atomic float**, float*** %136 unordered, align 8
  %137 = add i64 %arrayref91, -1
  %arrayptr244644 = load float*, float** %getfield2421810, align 8
  %138 = getelementptr inbounds float, float* %arrayptr244644, i64 %137
  %arrayref245 = load float, float* %138, align 4
  br label %L228

L228:                                             ; preds = %L223, %L218
  %value_phi92 = phi float [ %arrayref245, %L223 ], [ 0.000000e+00, %L218 ]
  br i1 %118, label %L232, label %L230

L230:                                             ; preds = %L228
  %139 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %139, align 8
  %140 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %140, align 16
  %141 = call float @j__coordinate_minimizer_1584({ double }* nocapture nonnull readonly %2, float %value_phi92, i64 signext %arrayref16)
  br label %L433

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
  br i1 %151, label %L251, label %L430

L251:                                             ; preds = %L232
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %152 = fcmp uge float %value_phi50, 0.000000e+00
  br i1 %152, label %L257, label %L255

L255:                                             ; preds = %L251
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %value_phi50) #2
  unreachable

L257:                                             ; preds = %L251
  %153 = call float @llvm.sqrt.f32(float %value_phi50)
  %154 = fcmp ugt float %153, %aggregate_load_box.sroa.0.0.copyload
  br i1 %154, label %L262, label %L433

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
  %200 = call float @j__sqrt_offrange_step_1590({}* nonnull %1, float %value_phi92, i64 signext %arrayref16)
  br label %L433

L317:                                             ; preds = %L306, %L262
  %value_phi214 = phi float [ %158, %L262 ], [ %value_phi212, %L306 ]
  %201 = fcmp uge float %value_phi214, 0.000000e+00
  br i1 %201, label %L322, label %L320

L320:                                             ; preds = %L317
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %value_phi214) #2
  unreachable

L322:                                             ; preds = %L317
  %202 = call float @llvm.sqrt.f32(float %value_phi214)
  %203 = fsub float %153, %aggregate_load_box.sroa.0.0.copyload
  %204 = fcmp uge float %203, 0.000000e+00
  br i1 %204, label %L329, label %L327

L327:                                             ; preds = %L322
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %203) #2
  unreachable

L329:                                             ; preds = %L322
  %205 = fadd float %153, %aggregate_load_box.sroa.0.0.copyload
  %206 = fcmp uge float %205, 0.000000e+00
  br i1 %206, label %L336, label %L334

L334:                                             ; preds = %L329
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %205) #2
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
  br label %L433

L427:                                             ; preds = %L336
  %225 = fpext float %202 to double
  %226 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %226, align 8
  %227 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %227, align 16
  %228 = call float @j__sqrt_band_step_1589(float %156, float %153, float %aggregate_load_box.sroa.0.0.copyload, double %225, i64 signext 0)
  br label %L433

L430:                                             ; preds = %L232
  %229 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %229, align 8
  %230 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 4
  store {}* %getfield18, {}** %230, align 16
  %231 = call float @j__sqrt_offrange_step_1590({}* nonnull %1, float %value_phi92, i64 signext %arrayref16)
  br label %L433

L433:                                             ; preds = %L430, %L427, %L370, %L315, %L257, %L230
  %value_phi93 = phi float [ %141, %L230 ], [ %200, %L315 ], [ %228, %L427 ], [ %231, %L430 ], [ 0.000000e+00, %L257 ], [ %224, %L370 ]
  %getfield95 = load atomic {}*, {}** %48 unordered, align 8
  %232 = bitcast {}* %getfield95 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr96 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %232, i64 0, i32 1
  %arraylen97 = load i64, i64* %arraylen_ptr96, align 8
  %inbounds98 = icmp ult i64 %49, %arraylen97
  br i1 %inbounds98, label %idxend101, label %oob99

L441:                                             ; preds = %idxend101
  %getfield117 = load atomic {}*, {}** %30 unordered, align 8
  %233 = bitcast {}* %getfield117 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr119 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %233, i64 0, i32 1
  %arraylen120 = load i64, i64* %arraylen_ptr119, align 8
  %.not623 = icmp ult i64 %49, %arraylen120
  br i1 %.not623, label %L455, label %L452

L452:                                             ; preds = %L441
  store i64 %arrayref16, i64* %35, align 8
  store {}* %getfield117, {}** %23, align 16
  call void @j_throw_boundserror_1586({}* nonnull %getfield117, [1 x i64]* nocapture readonly %newstruct118) #2
  unreachable

L455:                                             ; preds = %L441
  %234 = bitcast {}* %getfield117 to i64**
  %arrayptr125624 = load i64*, i64** %234, align 8
  %235 = getelementptr inbounds i64, i64* %arrayptr125624, i64 %49
  %arrayref126 = load i64, i64* %235, align 8
  %.not625 = icmp eq i64 %arrayref126, 0
  br i1 %.not625, label %L463, label %L460

L460:                                             ; preds = %L455
  %236 = bitcast {}* %0 to float***
  %getfield1281811 = load atomic float**, float*** %236 unordered, align 8
  %237 = add i64 %arrayref126, -1
  %arrayptr130626 = load float*, float** %getfield1281811, align 8
  %238 = getelementptr inbounds float, float* %arrayptr130626, i64 %237
  store float %value_phi93, float* %238, align 4
  br label %L480

L463:                                             ; preds = %L455
  %239 = fcmp oeq float %value_phi93, 0.000000e+00
  br i1 %239, label %L480, label %L466

L466:                                             ; preds = %L463
  %240 = load i64, i64* %37, align 8
  %241 = add i64 %240, 1
  store i64 %241, i64* %37, align 8
  %getfield153 = load atomic {}*, {}** %32 unordered, align 8
  %242 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %242, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %240, %arraylen155
  br i1 %inbounds156, label %idxend159, label %oob157

L480:                                             ; preds = %idxend179, %L463, %L460
  %getfield132 = load atomic {}*, {}** %47 unordered, align 8
  %243 = bitcast {}* %getfield132 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr135 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %243, i64 0, i32 1
  %arraylen136 = load i64, i64* %arraylen_ptr135, align 8
  %.not627 = icmp eq i64 %arraylen136, 0
  br i1 %.not627, label %L517, label %L493.lr.ph

L493.lr.ph:                                       ; preds = %L480
  %getfield134 = load atomic {}*, {}** %45 unordered, align 8
  %244 = bitcast {}* %getfield132 to float**
  %arrayptr141629 = load float*, float** %244, align 8
  %245 = bitcast {}* %getfield134 to {}**
  %arraysize_ptr143 = getelementptr inbounds {}*, {}** %245, i64 3
  %246 = bitcast {}** %arraysize_ptr143 to i64*
  %arraysize144 = load i64, i64* %246, align 8
  %247 = mul i64 %arraysize144, %49
  %248 = bitcast {}* %getfield134 to float**
  %arrayptr147630 = load float*, float** %248, align 8
  %min.iters.check = icmp ult i64 %arraylen136, 32
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L493.lr.ph
  %scevgep = getelementptr float, float* %arrayptr141629, i64 %arraylen136
  %scevgep1456 = getelementptr float, float* %arrayptr147630, i64 %247
  %249 = add i64 %arraylen136, %247
  %scevgep1458 = getelementptr float, float* %arrayptr147630, i64 %249
  %bound0 = icmp ult float* %arrayptr141629, %scevgep1458
  %bound1 = icmp ult float* %scevgep1456, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen136, 9223372036854775776
  %broadcast.splatinsert = insertelement <8 x float> poison, float %563, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %250 = getelementptr inbounds float, float* %arrayptr141629, i64 %index
  %251 = bitcast float* %250 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %251, align 4
  %252 = getelementptr inbounds float, float* %250, i64 8
  %253 = bitcast float* %252 to <8 x float>*
  %wide.load1460 = load <8 x float>, <8 x float>* %253, align 4
  %254 = getelementptr inbounds float, float* %250, i64 16
  %255 = bitcast float* %254 to <8 x float>*
  %wide.load1461 = load <8 x float>, <8 x float>* %255, align 4
  %256 = getelementptr inbounds float, float* %250, i64 24
  %257 = bitcast float* %256 to <8 x float>*
  %wide.load1462 = load <8 x float>, <8 x float>* %257, align 4
  %258 = add i64 %247, %index
  %259 = getelementptr inbounds float, float* %arrayptr147630, i64 %258
  %260 = bitcast float* %259 to <8 x float>*
  %wide.load1463 = load <8 x float>, <8 x float>* %260, align 4
  %261 = getelementptr inbounds float, float* %259, i64 8
  %262 = bitcast float* %261 to <8 x float>*
  %wide.load1464 = load <8 x float>, <8 x float>* %262, align 4
  %263 = getelementptr inbounds float, float* %259, i64 16
  %264 = bitcast float* %263 to <8 x float>*
  %wide.load1465 = load <8 x float>, <8 x float>* %264, align 4
  %265 = getelementptr inbounds float, float* %259, i64 24
  %266 = bitcast float* %265 to <8 x float>*
  %wide.load1466 = load <8 x float>, <8 x float>* %266, align 4
  %267 = fmul <8 x float> %broadcast.splat, %wide.load1463
  %268 = fmul <8 x float> %broadcast.splat, %wide.load1464
  %269 = fmul <8 x float> %broadcast.splat, %wide.load1465
  %270 = fmul <8 x float> %broadcast.splat, %wide.load1466
  %271 = fsub <8 x float> %wide.load, %267
  %272 = fsub <8 x float> %wide.load1460, %268
  %273 = fsub <8 x float> %wide.load1461, %269
  %274 = fsub <8 x float> %wide.load1462, %270
  store <8 x float> %271, <8 x float>* %251, align 4
  store <8 x float> %272, <8 x float>* %253, align 4
  store <8 x float> %273, <8 x float>* %255, align 4
  store <8 x float> %274, <8 x float>* %257, align 4
  %index.next = add nuw i64 %index, 32
  %275 = icmp eq i64 %index.next, %n.vec
  br i1 %275, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen136, %n.vec
  br i1 %cmp.n, label %L517, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L493.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L493.lr.ph ], [ 0, %vector.memcheck ]
  br label %L493

L493:                                             ; preds = %L493, %scalar.ph
  %value_phi139881 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %281, %L493 ]
  %276 = getelementptr inbounds float, float* %arrayptr141629, i64 %value_phi139881
  %arrayref142 = load float, float* %276, align 4
  %277 = add i64 %247, %value_phi139881
  %278 = getelementptr inbounds float, float* %arrayptr147630, i64 %277
  %arrayref148 = load float, float* %278, align 4
  %279 = fmul float %563, %arrayref148
  %280 = fsub float %arrayref142, %279
  store float %280, float* %276, align 4
  %281 = add nuw nsw i64 %value_phi139881, 1
  %exitcond1049.not = icmp eq i64 %281, %arraylen136
  br i1 %exitcond1049.not, label %L517, label %L493

L515:                                             ; preds = %L199
  call void @j__refuse_curvature_1591(i64 signext %arrayref16) #2
  unreachable

L517:                                             ; preds = %idxend101, %L493, %middle.block, %L480
  %arrayref16944 = phi i64 [ %arrayref16, %L480 ], [ %arrayref16945, %idxend101 ], [ %arrayref16, %middle.block ], [ %arrayref16, %L493 ]
  %282 = call float @llvm.fabs.f32(float %563)
  %283 = fcmp oeq float %563, 0.000000e+00
  %or.cond = select i1 %.not621, i1 true, i1 %283
  br i1 %or.cond, label %L528, label %L523

L523:                                             ; preds = %L517
  %getfield106 = load atomic {}*, {}** %28 unordered, align 8
  %284 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %24, {}** %284, align 8
  store {}* %getfield106, {}** %23, align 16
  %285 = call float @j_coordinate_scale_1585({}* nonnull %getfield106, {}* nonnull %0, i64 signext %arrayref16)
  %286 = fmul float %282, %285
  br label %L528

L528:                                             ; preds = %L523, %L517
  %value_phi107 = phi float [ %286, %L523 ], [ %282, %L517 ]
  %287 = fsub float %value_phi107, %value_phi107
  %288 = fcmp uno float %287, 0.000000e+00
  br i1 %288, label %L534, label %L537

L534:                                             ; preds = %L528
  store {}* inttoptr (i64 135794562993360 to {}*), {}** %6, align 8
  %289 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %289)
  unreachable

L537:                                             ; preds = %L528
  %.inv = fcmp olt float %value_phi7, %value_phi107
  %290 = select i1 %.inv, float %value_phi107, float %value_phi7
  %.not622.not = icmp eq i64 %value_phi5, %18
  %291 = add nuw i64 %value_phi5, 1
  br i1 %.not622.not, label %L1091.loopexit699, label %L30

L554:                                             ; preds = %top
  %.not649 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not649, label %L1091, label %L570.preheader

L570.preheader:                                   ; preds = %L554
  %292 = bitcast [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5 to i64***
  %getfield2841812 = load atomic i64**, i64*** %292 unordered, align 8
  %293 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 2
  %unbox285 = load i64, i64* %293, align 8
  %294 = bitcast {}* %1 to {}**
  %295 = bitcast {}* %0 to i8*
  %getfield_addr365 = getelementptr inbounds i8, i8* %295, i64 16
  %296 = bitcast i8* %getfield_addr365 to {}**
  %297 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct367, i64 0, i64 0
  %298 = bitcast {}* %0 to {}**
  %299 = bitcast {}* %1 to i8*
  %300 = getelementptr inbounds i8, i8* %299, i64 8
  %aggregate_load_box471.sroa.0.0..sroa_idx = bitcast i8* %300 to float*
  %301 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct400, i64 0, i64 0
  %302 = getelementptr inbounds i8, i8* %295, i64 24
  %303 = bitcast i8* %302 to i64*
  %getfield_addr444 = getelementptr inbounds i8, i8* %295, i64 8
  %304 = bitcast i8* %getfield_addr444 to {}**
  %305 = and i8 %4, 1
  %.not665 = icmp eq i8 %305, 0
  br label %L570

L570:                                             ; preds = %L1076, %L570.preheader
  %arrayref2881006 = phi i64 [ %arrayref2881005, %L1076 ], [ undef, %L570.preheader ]
  %value_phi276 = phi i64 [ %553, %L1076 ], [ 1, %L570.preheader ]
  %value_phi278 = phi float [ %552, %L1076 ], [ 0.000000e+00, %L570.preheader ]
  %306 = add nsw i64 %value_phi276, -1
  %307 = add i64 %306, %unbox285
  %arrayptr287651 = load i64*, i64** %getfield2841812, align 8
  %308 = getelementptr inbounds i64, i64* %arrayptr287651, i64 %307
  %arrayref288 = load i64, i64* %308, align 8
  %getfield290 = load atomic {}*, {}** %294 unordered, align 8
  %309 = bitcast {}* %getfield290 to {}**
  %getfield292 = load atomic {}*, {}** %309 unordered, align 8
  %310 = bitcast {}* %getfield290 to i8*
  %getfield_addr293 = getelementptr inbounds i8, i8* %310, i64 24
  %311 = bitcast i8* %getfield_addr293 to {}**
  %getfield294 = load atomic {}*, {}** %311 unordered, align 8
  %getfield_addr295 = getelementptr inbounds i8, i8* %310, i64 32
  %312 = bitcast i8* %getfield_addr295 to {}**
  %getfield296 = load atomic {}*, {}** %312 unordered, align 8
  %313 = add i64 %arrayref288, -1
  %314 = bitcast {}* %getfield296 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr297 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %314, i64 0, i32 1
  %arraylen298 = load i64, i64* %arraylen_ptr297, align 8
  %inbounds299 = icmp ult i64 %313, %arraylen298
  br i1 %inbounds299, label %idxend302, label %oob300

L606:                                             ; preds = %idxend302
  br i1 %.not691, label %L690, label %L620.lr.ph

L620.lr.ph:                                       ; preds = %L606
  %315 = bitcast {}* %getfield292 to {}**
  %arraysize_ptr314 = getelementptr inbounds {}*, {}** %315, i64 3
  %316 = bitcast {}** %arraysize_ptr314 to i64*
  %arraysize315 = load i64, i64* %316, align 8
  %317 = mul i64 %arraysize315, %313
  %318 = bitcast {}* %getfield292 to float**
  %arrayptr318655 = load float*, float** %318, align 8
  %319 = bitcast {}* %getfield294 to float**
  %arrayptr321656 = load float*, float** %319, align 8
  %min.iters.check1621 = icmp ult i64 %arraylen535, 8
  br i1 %min.iters.check1621, label %scalar.ph1620, label %vector.ph1622

vector.ph1622:                                    ; preds = %L620.lr.ph
  %n.vec1624 = and i64 %arraylen535, 9223372036854775800
  br label %vector.body1627

vector.body1627:                                  ; preds = %vector.body1627, %vector.ph1622
  %index1628 = phi i64 [ 0, %vector.ph1622 ], [ %index.next1634, %vector.body1627 ]
  %vec.phi1629 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %326, %vector.body1627 ]
  %vec.phi1630 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %328, %vector.body1627 ]
  %vec.phi1631 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1622 ], [ %330, %vector.body1627 ]
  %320 = add i64 %317, %index1628
  %321 = getelementptr inbounds float, float* %arrayptr318655, i64 %320
  %322 = bitcast float* %321 to <8 x float>*
  %wide.load1632 = load <8 x float>, <8 x float>* %322, align 4
  %323 = getelementptr inbounds float, float* %arrayptr321656, i64 %index1628
  %324 = bitcast float* %323 to <8 x float>*
  %wide.load1633 = load <8 x float>, <8 x float>* %324, align 4
  %325 = fmul contract <8 x float> %wide.load1632, %wide.load1632
  %326 = fadd reassoc contract <8 x float> %vec.phi1629, %325
  %327 = fmul contract <8 x float> %wide.load1632, %wide.load1633
  %328 = fadd reassoc contract <8 x float> %vec.phi1630, %327
  %329 = fmul contract <8 x float> %wide.load1633, %wide.load1633
  %330 = fadd reassoc contract <8 x float> %vec.phi1631, %329
  %index.next1634 = add nuw i64 %index1628, 8
  %331 = icmp eq i64 %index.next1634, %n.vec1624
  br i1 %331, label %middle.block1619, label %vector.body1627

middle.block1619:                                 ; preds = %vector.body1627
  %332 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %330)
  %333 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %328)
  %334 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %326)
  %cmp.n1626 = icmp eq i64 %arraylen535, %n.vec1624
  br i1 %cmp.n1626, label %L690, label %scalar.ph1620

scalar.ph1620:                                    ; preds = %middle.block1619, %L620.lr.ph
  %bc.resume.val1625 = phi i64 [ %n.vec1624, %middle.block1619 ], [ 0, %L620.lr.ph ]
  %bc.merge.rdx1635 = phi float [ %334, %middle.block1619 ], [ 0.000000e+00, %L620.lr.ph ]
  %bc.merge.rdx1636 = phi float [ %333, %middle.block1619 ], [ 0.000000e+00, %L620.lr.ph ]
  %bc.merge.rdx1637 = phi float [ %332, %middle.block1619 ], [ 0.000000e+00, %L620.lr.ph ]
  br label %L620

L620:                                             ; preds = %L620, %scalar.ph1620
  %value_phi313886 = phi float [ %bc.merge.rdx1635, %scalar.ph1620 ], [ %339, %L620 ]
  %value_phi312885 = phi i64 [ %bc.resume.val1625, %scalar.ph1620 ], [ %344, %L620 ]
  %value_phi311884 = phi float [ %bc.merge.rdx1636, %scalar.ph1620 ], [ %341, %L620 ]
  %value_phi310883 = phi float [ %bc.merge.rdx1637, %scalar.ph1620 ], [ %343, %L620 ]
  %335 = add i64 %317, %value_phi312885
  %336 = getelementptr inbounds float, float* %arrayptr318655, i64 %335
  %arrayref319 = load float, float* %336, align 4
  %337 = getelementptr inbounds float, float* %arrayptr321656, i64 %value_phi312885
  %arrayref322 = load float, float* %337, align 4
  %338 = fmul contract float %arrayref319, %arrayref319
  %339 = fadd reassoc contract float %value_phi313886, %338
  %340 = fmul contract float %arrayref319, %arrayref322
  %341 = fadd reassoc contract float %value_phi311884, %340
  %342 = fmul contract float %arrayref322, %arrayref322
  %343 = fadd reassoc contract float %value_phi310883, %342
  %344 = add nuw nsw i64 %value_phi312885, 1
  %exitcond1050.not = icmp eq i64 %344, %arraylen535
  br i1 %exitcond1050.not, label %L690, label %L620

L649:                                             ; preds = %idxend302
  br i1 %.not691, label %L690, label %L662.lr.ph

L662.lr.ph:                                       ; preds = %L649
  %345 = bitcast {}* %getfield292 to {}**
  %arraysize_ptr541 = getelementptr inbounds {}*, {}** %345, i64 3
  %346 = bitcast {}** %arraysize_ptr541 to i64*
  %arraysize542 = load i64, i64* %346, align 8
  %347 = mul i64 %arraysize542, %313
  %348 = bitcast {}* %getfield292 to float**
  %arrayptr545693 = load float*, float** %348, align 8
  %349 = bitcast {}* %getfield294 to float**
  %arrayptr548694 = load float*, float** %349, align 8
  %min.iters.check1598 = icmp ult i64 %arraylen535, 16
  br i1 %min.iters.check1598, label %scalar.ph1597, label %vector.ph1599

vector.ph1599:                                    ; preds = %L662.lr.ph
  %n.vec1601 = and i64 %arraylen535, 9223372036854775792
  br label %vector.body1604

vector.body1604:                                  ; preds = %vector.body1604, %vector.ph1599
  %index1605 = phi i64 [ 0, %vector.ph1599 ], [ %index.next1614, %vector.body1604 ]
  %vec.phi1606 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %361, %vector.body1604 ]
  %vec.phi1607 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %362, %vector.body1604 ]
  %vec.phi1608 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %365, %vector.body1604 ]
  %vec.phi1609 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1599 ], [ %366, %vector.body1604 ]
  %350 = add i64 %347, %index1605
  %351 = getelementptr inbounds float, float* %arrayptr545693, i64 %350
  %352 = bitcast float* %351 to <8 x float>*
  %wide.load1610 = load <8 x float>, <8 x float>* %352, align 4
  %353 = getelementptr inbounds float, float* %351, i64 8
  %354 = bitcast float* %353 to <8 x float>*
  %wide.load1611 = load <8 x float>, <8 x float>* %354, align 4
  %355 = getelementptr inbounds float, float* %arrayptr548694, i64 %index1605
  %356 = bitcast float* %355 to <8 x float>*
  %wide.load1612 = load <8 x float>, <8 x float>* %356, align 4
  %357 = getelementptr inbounds float, float* %355, i64 8
  %358 = bitcast float* %357 to <8 x float>*
  %wide.load1613 = load <8 x float>, <8 x float>* %358, align 4
  %359 = fmul contract <8 x float> %wide.load1610, %wide.load1612
  %360 = fmul contract <8 x float> %wide.load1611, %wide.load1613
  %361 = fadd reassoc contract <8 x float> %vec.phi1606, %359
  %362 = fadd reassoc contract <8 x float> %vec.phi1607, %360
  %363 = fmul contract <8 x float> %wide.load1612, %wide.load1612
  %364 = fmul contract <8 x float> %wide.load1613, %wide.load1613
  %365 = fadd reassoc contract <8 x float> %vec.phi1608, %363
  %366 = fadd reassoc contract <8 x float> %vec.phi1609, %364
  %index.next1614 = add nuw i64 %index1605, 16
  %367 = icmp eq i64 %index.next1614, %n.vec1601
  br i1 %367, label %middle.block1596, label %vector.body1604

middle.block1596:                                 ; preds = %vector.body1604
  %bin.rdx1617 = fadd reassoc contract <8 x float> %366, %365
  %368 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1617)
  %bin.rdx1615 = fadd reassoc contract <8 x float> %362, %361
  %369 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1615)
  %cmp.n1603 = icmp eq i64 %arraylen535, %n.vec1601
  br i1 %cmp.n1603, label %L690, label %scalar.ph1597

scalar.ph1597:                                    ; preds = %middle.block1596, %L662.lr.ph
  %bc.resume.val1602 = phi i64 [ %n.vec1601, %middle.block1596 ], [ 0, %L662.lr.ph ]
  %bc.merge.rdx1616 = phi float [ %369, %middle.block1596 ], [ 0.000000e+00, %L662.lr.ph ]
  %bc.merge.rdx1618 = phi float [ %368, %middle.block1596 ], [ 0.000000e+00, %L662.lr.ph ]
  br label %L662

L662:                                             ; preds = %L662, %scalar.ph1597
  %value_phi540893 = phi i64 [ %bc.resume.val1602, %scalar.ph1597 ], [ %377, %L662 ]
  %value_phi539892 = phi float [ %bc.merge.rdx1616, %scalar.ph1597 ], [ %374, %L662 ]
  %value_phi538891 = phi float [ %bc.merge.rdx1618, %scalar.ph1597 ], [ %376, %L662 ]
  %370 = add i64 %347, %value_phi540893
  %371 = getelementptr inbounds float, float* %arrayptr545693, i64 %370
  %arrayref546 = load float, float* %371, align 4
  %372 = getelementptr inbounds float, float* %arrayptr548694, i64 %value_phi540893
  %arrayref549 = load float, float* %372, align 4
  %373 = fmul contract float %arrayref546, %arrayref549
  %374 = fadd reassoc contract float %value_phi539892, %373
  %375 = fmul contract float %arrayref549, %arrayref549
  %376 = fadd reassoc contract float %value_phi538891, %375
  %377 = add nuw nsw i64 %value_phi540893, 1
  %exitcond1051.not = icmp eq i64 %377, %arraylen535
  br i1 %exitcond1051.not, label %L690, label %L662

L690:                                             ; preds = %L662, %middle.block1596, %L649, %L620, %middle.block1619, %L606
  %value_phi330 = phi float [ 0.000000e+00, %L606 ], [ 0.000000e+00, %L649 ], [ %368, %middle.block1596 ], [ %332, %middle.block1619 ], [ %376, %L662 ], [ %343, %L620 ]
  %value_phi331 = phi float [ 0.000000e+00, %L606 ], [ 0.000000e+00, %L649 ], [ %369, %middle.block1596 ], [ %333, %middle.block1619 ], [ %374, %L662 ], [ %341, %L620 ]
  %value_phi332 = phi float [ 0.000000e+00, %L606 ], [ %arrayref305, %L649 ], [ %arrayref305, %middle.block1596 ], [ %334, %middle.block1619 ], [ %arrayref305, %L662 ], [ %339, %L620 ]
  %378 = fsub float %value_phi330, %value_phi330
  %379 = fcmp uno float %378, 0.000000e+00
  br i1 %379, label %L695, label %L697

L695:                                             ; preds = %L690
  %380 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield290, {}** %380, align 8
  %381 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield294, {}** %381, align 16
  call void @j__check_residual_1592({}* nonnull %getfield294, i64 signext %arrayref288)
  br label %L697

L697:                                             ; preds = %L695, %L690
  %382 = fcmp une float %value_phi332, 0.000000e+00
  br i1 %382, label %L738, label %L699

L699:                                             ; preds = %L697
  %getfield334 = load atomic {}*, {}** %309 unordered, align 8
  %383 = bitcast {}* %getfield334 to {}**
  %arraysize_ptr335 = getelementptr inbounds {}*, {}** %383, i64 3
  %384 = bitcast {}** %arraysize_ptr335 to i64*
  %arraysize336 = load i64, i64* %384, align 8
  %.not657.not = icmp eq i64 %arraysize336, 0
  br i1 %.not657.not, label %L738, label %L712.preheader

L712.preheader:                                   ; preds = %L699
  %arraysize_ptr350 = getelementptr inbounds {}*, {}** %383, i64 4
  %385 = bitcast {}** %arraysize_ptr350 to i64*
  %arraysize351 = load i64, i64* %385, align 8
  %inbounds352 = icmp ult i64 %313, %arraysize351
  %386 = mul i64 %arraysize336, %313
  %387 = bitcast {}* %getfield334 to float**
  %arrayptr357659 = load float*, float** %387, align 8
  %inbounds352.fr = freeze i1 %inbounds352
  br i1 %inbounds352.fr, label %ib348.us, label %oob353

ib348.us:                                         ; preds = %L718.us, %L712.preheader
  %value_phi341.us = phi i64 [ %392, %L718.us ], [ 1, %L712.preheader ]
  %388 = add nsw i64 %value_phi341.us, -1
  %389 = add i64 %386, %388
  %390 = getelementptr inbounds float, float* %arrayptr357659, i64 %389
  %arrayref358.us = load float, float* %390, align 4
  %391 = fcmp une float %arrayref358.us, 0.000000e+00
  br i1 %391, label %L734.split.us, label %L718.us

L718.us:                                          ; preds = %ib348.us
  %392 = add nuw nsw i64 %value_phi341.us, 1
  %393 = icmp ult i64 %value_phi341.us, %arraysize336
  br i1 %393, label %ib348.us, label %L738

L734.split.us:                                    ; preds = %ib348.us
  store {}* inttoptr (i64 135794568225424 to {}*), {}** %6, align 8
  %394 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %394)
  unreachable

L738:                                             ; preds = %L718.us, %L699, %L697
  %395 = fsub float %value_phi332, %value_phi332
  %396 = fcmp uno float %395, 0.000000e+00
  br i1 %396, label %L1054, label %L743

L743:                                             ; preds = %L738
  %getfield366 = load atomic {}*, {}** %296 unordered, align 8
  %397 = bitcast {}* %getfield366 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr368 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %397, i64 0, i32 1
  %arraylen369 = load i64, i64* %arraylen_ptr368, align 8
  %.not661 = icmp ult i64 %313, %arraylen369
  br i1 %.not661, label %L757, label %L754

L754:                                             ; preds = %L743
  store i64 %arrayref288, i64* %297, align 8
  %398 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield366, {}** %398, align 16
  call void @j_throw_boundserror_1586({}* nonnull %getfield366, [1 x i64]* nocapture readonly %newstruct367) #2
  unreachable

L757:                                             ; preds = %L743
  %399 = bitcast {}* %getfield366 to i64**
  %arrayptr374662 = load i64*, i64** %399, align 8
  %400 = getelementptr inbounds i64, i64* %arrayptr374662, i64 %313
  %arrayref375 = load i64, i64* %400, align 8
  %.not663 = icmp eq i64 %arrayref375, 0
  br i1 %.not663, label %L767, label %L762

L762:                                             ; preds = %L757
  %401 = bitcast {}* %0 to float***
  %getfield5261813 = load atomic float**, float*** %401 unordered, align 8
  %402 = add i64 %arrayref375, -1
  %arrayptr528690 = load float*, float** %getfield5261813, align 8
  %403 = getelementptr inbounds float, float* %arrayptr528690, i64 %402
  %arrayref529 = load float, float* %403, align 4
  br label %L767

L767:                                             ; preds = %L762, %L757
  %value_phi376 = phi float [ %arrayref529, %L762 ], [ 0.000000e+00, %L757 ]
  br i1 %382, label %L771, label %L769

L769:                                             ; preds = %L767
  %404 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield290, {}** %404, align 8
  %405 = call float @j__coordinate_minimizer_1584({ double }* nocapture nonnull readonly %2, float %value_phi376, i64 signext %arrayref288)
  br label %L972

L771:                                             ; preds = %L767
  %getfield466 = load atomic {}*, {}** %294 unordered, align 8
  %406 = bitcast {}* %getfield466 to i8*
  %getfield_addr467 = getelementptr inbounds i8, i8* %406, i64 24
  %407 = bitcast i8* %getfield_addr467 to {}**
  %getfield468 = load atomic {}*, {}** %407 unordered, align 8
  %408 = bitcast {}* %getfield468 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr469 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %408, i64 0, i32 1
  %arraylen470 = load i64, i64* %arraylen_ptr469, align 8
  %409 = sitofp i64 %arraylen470 to float
  %410 = fmul float %409, 0x3980000000000000
  %411 = fcmp ole float %410, %value_phi332
  %412 = fcmp ord float %378, 0.000000e+00
  %413 = fcmp ole float %410, %value_phi330
  %414 = and i1 %412, %413
  %415 = and i1 %411, %414
  br i1 %415, label %L790, label %L969

L790:                                             ; preds = %L771
  %aggregate_load_box471.sroa.0.0.copyload = load float, float* %aggregate_load_box471.sroa.0.0..sroa_idx, align 1
  %416 = fcmp uge float %value_phi332, 0.000000e+00
  br i1 %416, label %L796, label %L794

L794:                                             ; preds = %L790
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %value_phi332) #2
  unreachable

L796:                                             ; preds = %L790
  %417 = call float @llvm.sqrt.f32(float %value_phi332)
  %418 = fcmp ugt float %417, %aggregate_load_box471.sroa.0.0.copyload
  br i1 %418, label %L801, label %L972

L801:                                             ; preds = %L796
  %419 = fdiv float %value_phi331, %value_phi332
  %420 = fadd float %419, %value_phi376
  %421 = fmul float %value_phi331, %419
  %422 = fsub float %value_phi330, %421
  %423 = fmul float %value_phi330, 6.250000e-02
  %424 = fcmp uge float %422, %423
  br i1 %424, label %L856, label %L808

L808:                                             ; preds = %L801
  %.not680 = icmp eq i64 %arraylen470, 0
  br i1 %.not680, label %L845, label %L822.lr.ph

L822.lr.ph:                                       ; preds = %L808
  %425 = bitcast {}* %getfield466 to {}**
  %getfield476 = load atomic {}*, {}** %425 unordered, align 8
  %426 = bitcast {}* %getfield468 to float**
  %arrayptr486682 = load float*, float** %426, align 8
  %427 = bitcast {}* %getfield476 to {}**
  %arraysize_ptr488 = getelementptr inbounds {}*, {}** %427, i64 3
  %428 = bitcast {}** %arraysize_ptr488 to i64*
  %arraysize489 = load i64, i64* %428, align 8
  %429 = mul i64 %arraysize489, %313
  %430 = bitcast {}* %getfield476 to float**
  %arrayptr492683 = load float*, float** %430, align 8
  %min.iters.check1575 = icmp ult i64 %arraylen470, 16
  br i1 %min.iters.check1575, label %scalar.ph1574, label %vector.ph1576

vector.ph1576:                                    ; preds = %L822.lr.ph
  %n.vec1578 = and i64 %arraylen470, 9223372036854775792
  %broadcast.splatinsert1589 = insertelement <8 x float> poison, float %419, i64 0
  %broadcast.splat1590 = shufflevector <8 x float> %broadcast.splatinsert1589, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1581

vector.body1581:                                  ; preds = %vector.body1581, %vector.ph1576
  %index1582 = phi i64 [ 0, %vector.ph1576 ], [ %index.next1593, %vector.body1581 ]
  %vec.phi1583 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1576 ], [ %446, %vector.body1581 ]
  %vec.phi1584 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph1576 ], [ %447, %vector.body1581 ]
  %431 = getelementptr inbounds float, float* %arrayptr486682, i64 %index1582
  %432 = bitcast float* %431 to <8 x float>*
  %wide.load1585 = load <8 x float>, <8 x float>* %432, align 4
  %433 = getelementptr inbounds float, float* %431, i64 8
  %434 = bitcast float* %433 to <8 x float>*
  %wide.load1586 = load <8 x float>, <8 x float>* %434, align 4
  %435 = add i64 %429, %index1582
  %436 = getelementptr inbounds float, float* %arrayptr492683, i64 %435
  %437 = bitcast float* %436 to <8 x float>*
  %wide.load1587 = load <8 x float>, <8 x float>* %437, align 4
  %438 = getelementptr inbounds float, float* %436, i64 8
  %439 = bitcast float* %438 to <8 x float>*
  %wide.load1588 = load <8 x float>, <8 x float>* %439, align 4
  %440 = fmul <8 x float> %broadcast.splat1590, %wide.load1587
  %441 = fmul <8 x float> %broadcast.splat1590, %wide.load1588
  %442 = fsub <8 x float> %wide.load1585, %440
  %443 = fsub <8 x float> %wide.load1586, %441
  %444 = fmul contract <8 x float> %442, %442
  %445 = fmul contract <8 x float> %443, %443
  %446 = fadd reassoc contract <8 x float> %vec.phi1583, %444
  %447 = fadd reassoc contract <8 x float> %vec.phi1584, %445
  %index.next1593 = add nuw i64 %index1582, 16
  %448 = icmp eq i64 %index.next1593, %n.vec1578
  br i1 %448, label %middle.block1573, label %vector.body1581

middle.block1573:                                 ; preds = %vector.body1581
  %bin.rdx1594 = fadd reassoc contract <8 x float> %447, %446
  %449 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx1594)
  %cmp.n1580 = icmp eq i64 %arraylen470, %n.vec1578
  br i1 %cmp.n1580, label %L845, label %scalar.ph1574

scalar.ph1574:                                    ; preds = %middle.block1573, %L822.lr.ph
  %bc.resume.val1579 = phi i64 [ %n.vec1578, %middle.block1573 ], [ 0, %L822.lr.ph ]
  %bc.merge.rdx1595 = phi float [ %449, %middle.block1573 ], [ 0.000000e+00, %L822.lr.ph ]
  br label %L822

L822:                                             ; preds = %L822, %scalar.ph1574
  %value_phi484898 = phi i64 [ %bc.resume.val1579, %scalar.ph1574 ], [ %457, %L822 ]
  %value_phi483897 = phi float [ %bc.merge.rdx1595, %scalar.ph1574 ], [ %456, %L822 ]
  %450 = getelementptr inbounds float, float* %arrayptr486682, i64 %value_phi484898
  %arrayref487 = load float, float* %450, align 4
  %451 = add i64 %429, %value_phi484898
  %452 = getelementptr inbounds float, float* %arrayptr492683, i64 %451
  %arrayref493 = load float, float* %452, align 4
  %453 = fmul float %419, %arrayref493
  %454 = fsub float %arrayref487, %453
  %455 = fmul contract float %454, %454
  %456 = fadd reassoc contract float %value_phi483897, %455
  %457 = add nuw nsw i64 %value_phi484898, 1
  %exitcond1052.not = icmp eq i64 %457, %arraylen470
  br i1 %exitcond1052.not, label %L845, label %L822

L845:                                             ; preds = %L822, %middle.block1573, %L808
  %value_phi495 = phi float [ 0.000000e+00, %L808 ], [ %449, %middle.block1573 ], [ %456, %L822 ]
  %458 = fsub float %value_phi495, %value_phi495
  %459 = fcmp uno float %458, 0.000000e+00
  %460 = fcmp ugt float %410, %value_phi495
  %461 = or i1 %460, %459
  br i1 %461, label %L854, label %L856

L854:                                             ; preds = %L845
  %462 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield290, {}** %462, align 8
  %463 = call float @j__sqrt_offrange_step_1590({}* nonnull %1, float %value_phi376, i64 signext %arrayref288)
  br label %L972

L856:                                             ; preds = %L845, %L801
  %value_phi497 = phi float [ %422, %L801 ], [ %value_phi495, %L845 ]
  %464 = fcmp uge float %value_phi497, 0.000000e+00
  br i1 %464, label %L861, label %L859

L859:                                             ; preds = %L856
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %value_phi497) #2
  unreachable

L861:                                             ; preds = %L856
  %465 = call float @llvm.sqrt.f32(float %value_phi497)
  %466 = fsub float %417, %aggregate_load_box471.sroa.0.0.copyload
  %467 = fcmp uge float %466, 0.000000e+00
  br i1 %467, label %L868, label %L866

L866:                                             ; preds = %L861
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %466) #2
  unreachable

L868:                                             ; preds = %L861
  %468 = fadd float %417, %aggregate_load_box471.sroa.0.0.copyload
  %469 = fcmp uge float %468, 0.000000e+00
  br i1 %469, label %L875, label %L873

L873:                                             ; preds = %L868
  call void @j_throw_complex_domainerror_1587({}* inttoptr (i64 135794596555280 to {}*), float %468) #2
  unreachable

L875:                                             ; preds = %L868
  %470 = call float @llvm.sqrt.f32(float %466)
  %471 = call float @llvm.sqrt.f32(float %468)
  %472 = fmul float %470, %471
  %473 = fmul float %417, %472
  %474 = fdiv float %465, %473
  %475 = fmul float %aggregate_load_box471.sroa.0.0.copyload, %474
  %476 = fcmp oge float %473, 0x3810000000000000
  %477 = fcmp oge float %474, 0x3810000000000000
  %478 = fcmp ole float %474, 0x47EFFFFFE0000000
  %narrow684 = and i1 %477, %478
  %479 = and i1 %476, %narrow684
  %480 = fcmp oge float %475, 0x3810000000000000
  %481 = fcmp ole float %475, 0x47EFFFFFE0000000
  %narrow685 = and i1 %480, %481
  %482 = and i1 %479, %narrow685
  br i1 %482, label %L909, label %L966

L909:                                             ; preds = %L875
  %483 = fneg float %475
  %.inv687 = fcmp ogt float %420, %483
  %484 = select i1 %.inv687, float %420, float %483
  %.inv688 = fcmp olt float %484, %475
  %485 = select i1 %.inv688, float %484, float %475
  %486 = fsub float %420, %485
  %487 = fadd float %486, 0.000000e+00
  br label %L972

L966:                                             ; preds = %L875
  %488 = fpext float %465 to double
  %489 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield290, {}** %489, align 8
  %490 = call float @j__sqrt_band_step_1589(float %420, float %417, float %aggregate_load_box471.sroa.0.0.copyload, double %488, i64 signext 0)
  br label %L972

L969:                                             ; preds = %L771
  %491 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 3
  store {}* %getfield290, {}** %491, align 8
  %492 = call float @j__sqrt_offrange_step_1590({}* nonnull %1, float %value_phi376, i64 signext %arrayref288)
  br label %L972

L972:                                             ; preds = %L969, %L966, %L909, %L854, %L796, %L769
  %value_phi377 = phi float [ %405, %L769 ], [ %463, %L854 ], [ %490, %L966 ], [ %492, %L969 ], [ 0.000000e+00, %L796 ], [ %487, %L909 ]
  %getfield379 = load atomic {}*, {}** %312 unordered, align 8
  %493 = bitcast {}* %getfield379 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr380 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %493, i64 0, i32 1
  %arraylen381 = load i64, i64* %arraylen_ptr380, align 8
  %inbounds382 = icmp ult i64 %313, %arraylen381
  br i1 %inbounds382, label %idxend385, label %oob383

L980:                                             ; preds = %idxend385
  %getfield399 = load atomic {}*, {}** %296 unordered, align 8
  %494 = bitcast {}* %getfield399 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr401 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %494, i64 0, i32 1
  %arraylen402 = load i64, i64* %arraylen_ptr401, align 8
  %.not668 = icmp ult i64 %313, %arraylen402
  br i1 %.not668, label %L994, label %L991

L991:                                             ; preds = %L980
  store i64 %arrayref288, i64* %301, align 8
  %495 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield399, {}** %495, align 16
  call void @j_throw_boundserror_1586({}* nonnull %getfield399, [1 x i64]* nocapture readonly %newstruct400) #2
  unreachable

L994:                                             ; preds = %L980
  %496 = bitcast {}* %getfield399 to i64**
  %arrayptr407669 = load i64*, i64** %496, align 8
  %497 = getelementptr inbounds i64, i64* %arrayptr407669, i64 %313
  %arrayref408 = load i64, i64* %497, align 8
  %.not670 = icmp eq i64 %arrayref408, 0
  br i1 %.not670, label %L1002, label %L999

L999:                                             ; preds = %L994
  %498 = bitcast {}* %0 to float***
  %getfield4101814 = load atomic float**, float*** %498 unordered, align 8
  %499 = add i64 %arrayref408, -1
  %arrayptr412671 = load float*, float** %getfield4101814, align 8
  %500 = getelementptr inbounds float, float* %arrayptr412671, i64 %499
  store float %value_phi377, float* %500, align 4
  br label %L1019

L1002:                                            ; preds = %L994
  %501 = fcmp oeq float %value_phi377, 0.000000e+00
  br i1 %501, label %L1019, label %L1005

L1005:                                            ; preds = %L1002
  %502 = load i64, i64* %303, align 8
  %503 = add i64 %502, 1
  store i64 %503, i64* %303, align 8
  %getfield435 = load atomic {}*, {}** %298 unordered, align 8
  %504 = bitcast {}* %getfield435 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr436 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %504, i64 0, i32 1
  %arraylen437 = load i64, i64* %arraylen_ptr436, align 8
  %inbounds438 = icmp ult i64 %502, %arraylen437
  br i1 %inbounds438, label %idxend441, label %oob439

L1019:                                            ; preds = %idxend461, %L1002, %L999
  %getfield414 = load atomic {}*, {}** %311 unordered, align 8
  %505 = bitcast {}* %getfield414 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr417 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %505, i64 0, i32 1
  %arraylen418 = load i64, i64* %arraylen_ptr417, align 8
  %.not672 = icmp eq i64 %arraylen418, 0
  br i1 %.not672, label %L1056, label %L1032.lr.ph

L1032.lr.ph:                                      ; preds = %L1019
  %getfield416 = load atomic {}*, {}** %309 unordered, align 8
  %506 = bitcast {}* %getfield414 to float**
  %arrayptr423674 = load float*, float** %506, align 8
  %507 = bitcast {}* %getfield416 to {}**
  %arraysize_ptr425 = getelementptr inbounds {}*, {}** %507, i64 3
  %508 = bitcast {}** %arraysize_ptr425 to i64*
  %arraysize426 = load i64, i64* %508, align 8
  %509 = mul i64 %arraysize426, %313
  %510 = bitcast {}* %getfield416 to float**
  %arrayptr429675 = load float*, float** %510, align 8
  %min.iters.check1548 = icmp ult i64 %arraylen418, 32
  br i1 %min.iters.check1548, label %scalar.ph1547, label %vector.memcheck1535

vector.memcheck1535:                              ; preds = %L1032.lr.ph
  %scevgep1537 = getelementptr float, float* %arrayptr423674, i64 %arraylen418
  %scevgep1539 = getelementptr float, float* %arrayptr429675, i64 %509
  %511 = add i64 %arraylen418, %509
  %scevgep1541 = getelementptr float, float* %arrayptr429675, i64 %511
  %bound01543 = icmp ult float* %arrayptr423674, %scevgep1541
  %bound11544 = icmp ult float* %scevgep1539, %scevgep1537
  %found.conflict1545 = and i1 %bound01543, %bound11544
  br i1 %found.conflict1545, label %scalar.ph1547, label %vector.ph1549

vector.ph1549:                                    ; preds = %vector.memcheck1535
  %n.vec1551 = and i64 %arraylen418, 9223372036854775776
  %broadcast.splatinsert1564 = insertelement <8 x float> poison, float %577, i64 0
  %broadcast.splat1565 = shufflevector <8 x float> %broadcast.splatinsert1564, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body1554

vector.body1554:                                  ; preds = %vector.body1554, %vector.ph1549
  %index1555 = phi i64 [ 0, %vector.ph1549 ], [ %index.next1572, %vector.body1554 ]
  %512 = getelementptr inbounds float, float* %arrayptr423674, i64 %index1555
  %513 = bitcast float* %512 to <8 x float>*
  %wide.load1556 = load <8 x float>, <8 x float>* %513, align 4
  %514 = getelementptr inbounds float, float* %512, i64 8
  %515 = bitcast float* %514 to <8 x float>*
  %wide.load1557 = load <8 x float>, <8 x float>* %515, align 4
  %516 = getelementptr inbounds float, float* %512, i64 16
  %517 = bitcast float* %516 to <8 x float>*
  %wide.load1558 = load <8 x float>, <8 x float>* %517, align 4
  %518 = getelementptr inbounds float, float* %512, i64 24
  %519 = bitcast float* %518 to <8 x float>*
  %wide.load1559 = load <8 x float>, <8 x float>* %519, align 4
  %520 = add i64 %509, %index1555
  %521 = getelementptr inbounds float, float* %arrayptr429675, i64 %520
  %522 = bitcast float* %521 to <8 x float>*
  %wide.load1560 = load <8 x float>, <8 x float>* %522, align 4
  %523 = getelementptr inbounds float, float* %521, i64 8
  %524 = bitcast float* %523 to <8 x float>*
  %wide.load1561 = load <8 x float>, <8 x float>* %524, align 4
  %525 = getelementptr inbounds float, float* %521, i64 16
  %526 = bitcast float* %525 to <8 x float>*
  %wide.load1562 = load <8 x float>, <8 x float>* %526, align 4
  %527 = getelementptr inbounds float, float* %521, i64 24
  %528 = bitcast float* %527 to <8 x float>*
  %wide.load1563 = load <8 x float>, <8 x float>* %528, align 4
  %529 = fmul <8 x float> %broadcast.splat1565, %wide.load1560
  %530 = fmul <8 x float> %broadcast.splat1565, %wide.load1561
  %531 = fmul <8 x float> %broadcast.splat1565, %wide.load1562
  %532 = fmul <8 x float> %broadcast.splat1565, %wide.load1563
  %533 = fsub <8 x float> %wide.load1556, %529
  %534 = fsub <8 x float> %wide.load1557, %530
  %535 = fsub <8 x float> %wide.load1558, %531
  %536 = fsub <8 x float> %wide.load1559, %532
  store <8 x float> %533, <8 x float>* %513, align 4
  store <8 x float> %534, <8 x float>* %515, align 4
  store <8 x float> %535, <8 x float>* %517, align 4
  store <8 x float> %536, <8 x float>* %519, align 4
  %index.next1572 = add nuw i64 %index1555, 32
  %537 = icmp eq i64 %index.next1572, %n.vec1551
  br i1 %537, label %middle.block1546, label %vector.body1554

middle.block1546:                                 ; preds = %vector.body1554
  %cmp.n1553 = icmp eq i64 %arraylen418, %n.vec1551
  br i1 %cmp.n1553, label %L1056, label %scalar.ph1547

scalar.ph1547:                                    ; preds = %middle.block1546, %vector.memcheck1535, %L1032.lr.ph
  %bc.resume.val1552 = phi i64 [ %n.vec1551, %middle.block1546 ], [ 0, %L1032.lr.ph ], [ 0, %vector.memcheck1535 ]
  br label %L1032

L1032:                                            ; preds = %L1032, %scalar.ph1547
  %value_phi421901 = phi i64 [ %bc.resume.val1552, %scalar.ph1547 ], [ %543, %L1032 ]
  %538 = getelementptr inbounds float, float* %arrayptr423674, i64 %value_phi421901
  %arrayref424 = load float, float* %538, align 4
  %539 = add i64 %509, %value_phi421901
  %540 = getelementptr inbounds float, float* %arrayptr429675, i64 %539
  %arrayref430 = load float, float* %540, align 4
  %541 = fmul float %577, %arrayref430
  %542 = fsub float %arrayref424, %541
  store float %542, float* %538, align 4
  %543 = add nuw nsw i64 %value_phi421901, 1
  %exitcond1053.not = icmp eq i64 %543, %arraylen418
  br i1 %exitcond1053.not, label %L1056, label %L1032

L1054:                                            ; preds = %L738
  call void @j__refuse_curvature_1591(i64 signext %arrayref288) #2
  unreachable

L1056:                                            ; preds = %idxend385, %L1032, %middle.block1546, %L1019
  %arrayref2881005 = phi i64 [ %arrayref288, %L1019 ], [ %arrayref2881006, %idxend385 ], [ %arrayref288, %middle.block1546 ], [ %arrayref288, %L1032 ]
  %544 = call float @llvm.fabs.f32(float %577)
  %545 = fcmp oeq float %577, 0.000000e+00
  %or.cond1302 = select i1 %.not665, i1 true, i1 %545
  br i1 %or.cond1302, label %L1067, label %L1062

L1062:                                            ; preds = %L1056
  %getfield390 = load atomic {}*, {}** %294 unordered, align 8
  %546 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1808, i64 0, i64 2
  store {}* %getfield390, {}** %546, align 16
  %547 = call float @j_coordinate_scale_1585({}* nonnull %getfield390, {}* nonnull %0, i64 signext %arrayref288)
  %548 = fmul float %544, %547
  br label %L1067

L1067:                                            ; preds = %L1062, %L1056
  %value_phi391 = phi float [ %548, %L1062 ], [ %544, %L1056 ]
  %549 = fsub float %value_phi391, %value_phi391
  %550 = fcmp uno float %549, 0.000000e+00
  br i1 %550, label %L1073, label %L1076

L1073:                                            ; preds = %L1067
  store {}* inttoptr (i64 135794562993360 to {}*), {}** %6, align 8
  %551 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %551)
  unreachable

L1076:                                            ; preds = %L1067
  %.inv666 = fcmp olt float %value_phi278, %value_phi391
  %552 = select i1 %.inv666, float %value_phi391, float %value_phi278
  %.not667.not = icmp eq i64 %value_phi276, %18
  %553 = add nuw i64 %value_phi276, 1
  br i1 %.not667.not, label %L1091.loopexit, label %L570

L1091.loopexit:                                   ; preds = %L1076
  store i64 %arrayref288, i64* %297, align 8
  store i64 %arrayref2881005, i64* %301, align 8
  br label %L1091

L1091.loopexit699:                                ; preds = %L537
  store i64 %arrayref16, i64* %31, align 8
  store i64 %arrayref16944, i64* %35, align 8
  br label %L1091

L1091:                                            ; preds = %L1091.loopexit699, %L1091.loopexit, %L554, %L12
  %value_phi113 = phi float [ 0.000000e+00, %L12 ], [ 0.000000e+00, %L554 ], [ %552, %L1091.loopexit ], [ %290, %L1091.loopexit699 ]
  %554 = load {}*, {}** %10, align 8
  %555 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %554, {}** %555, align 8
  ret float %value_phi113

oob:                                              ; preds = %L30
  %errorbox = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield24, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L30
  %556 = bitcast {}* %getfield24 to float**
  %arrayptr26608 = load float*, float** %556, align 8
  %557 = getelementptr inbounds float, float* %arrayptr26608, i64 %49
  %arrayref27 = load float, float* %557, align 4
  %558 = fcmp ord float %arrayref27, 0.000000e+00
  %559 = bitcast {}* %getfield22 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr250 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %559, i64 0, i32 1
  %arraylen251 = load i64, i64* %arraylen_ptr250, align 8
  %.not645 = icmp eq i64 %arraylen251, 0
  br i1 %558, label %L110, label %L67

oob70:                                            ; preds = %L173.preheader
  %errorbox71614 = alloca [2 x i64], align 8
  %errorbox71614.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 0
  store i64 1, i64* %errorbox71614.sub, align 8
  %560 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 1
  store i64 %arrayref16, i64* %560, align 8
  call void @ijl_bounds_error_ints({}* %getfield52, i64* nonnull %errorbox71614.sub, i64 2)
  unreachable

oob99:                                            ; preds = %L433
  %errorbox100 = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox100, align 8
  call void @ijl_bounds_error_ints({}* %getfield95, i64* nonnull %errorbox100, i64 1)
  unreachable

idxend101:                                        ; preds = %L433
  %561 = bitcast {}* %getfield95 to float**
  %arrayptr103620 = load float*, float** %561, align 8
  %562 = getelementptr inbounds float, float* %arrayptr103620, i64 %49
  store float %value_phi50, float* %562, align 4
  %563 = fsub float %value_phi93, %value_phi92
  %564 = fcmp une float %563, 0.000000e+00
  br i1 %564, label %L441, label %L517

oob157:                                           ; preds = %L466
  %errorbox158 = alloca i64, align 8
  store i64 %241, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend159:                                        ; preds = %L466
  %565 = bitcast {}* %getfield153 to float**
  %arrayptr161632 = load float*, float** %565, align 8
  %566 = getelementptr inbounds float, float* %arrayptr161632, i64 %240
  store float %value_phi93, float* %566, align 4
  %getfield163 = load atomic {}*, {}** %38 unordered, align 8
  %567 = bitcast {}* %getfield163 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr164 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %567, i64 0, i32 1
  %arraylen165 = load i64, i64* %arraylen_ptr164, align 8
  %inbounds166 = icmp ult i64 %240, %arraylen165
  br i1 %inbounds166, label %idxend179, label %oob167

oob167:                                           ; preds = %idxend159
  %errorbox168 = alloca i64, align 8
  store i64 %241, i64* %errorbox168, align 8
  call void @ijl_bounds_error_ints({}* %getfield163, i64* nonnull %errorbox168, i64 1)
  unreachable

idxend179:                                        ; preds = %idxend159
  %568 = bitcast {}* %getfield163 to i64**
  %arrayptr171633 = load i64*, i64** %568, align 8
  %569 = getelementptr inbounds i64, i64* %arrayptr171633, i64 %240
  store i64 %arrayref16, i64* %569, align 8
  store i64 %241, i64* %235, align 8
  br label %L480

oob300:                                           ; preds = %L570
  %errorbox301 = alloca i64, align 8
  store i64 %arrayref288, i64* %errorbox301, align 8
  call void @ijl_bounds_error_ints({}* %getfield296, i64* nonnull %errorbox301, i64 1)
  unreachable

idxend302:                                        ; preds = %L570
  %570 = bitcast {}* %getfield296 to float**
  %arrayptr304652 = load float*, float** %570, align 8
  %571 = getelementptr inbounds float, float* %arrayptr304652, i64 %313
  %arrayref305 = load float, float* %571, align 4
  %572 = fcmp ord float %arrayref305, 0.000000e+00
  %573 = bitcast {}* %getfield294 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr534 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %573, i64 0, i32 1
  %arraylen535 = load i64, i64* %arraylen_ptr534, align 8
  %.not691 = icmp eq i64 %arraylen535, 0
  br i1 %572, label %L649, label %L606

oob353:                                           ; preds = %L712.preheader
  %errorbox354658 = alloca [2 x i64], align 8
  %errorbox354658.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox354658, i64 0, i64 0
  store i64 1, i64* %errorbox354658.sub, align 8
  %574 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox354658, i64 0, i64 1
  store i64 %arrayref288, i64* %574, align 8
  call void @ijl_bounds_error_ints({}* %getfield334, i64* nonnull %errorbox354658.sub, i64 2)
  unreachable

oob383:                                           ; preds = %L972
  %errorbox384 = alloca i64, align 8
  store i64 %arrayref288, i64* %errorbox384, align 8
  call void @ijl_bounds_error_ints({}* %getfield379, i64* nonnull %errorbox384, i64 1)
  unreachable

idxend385:                                        ; preds = %L972
  %575 = bitcast {}* %getfield379 to float**
  %arrayptr387664 = load float*, float** %575, align 8
  %576 = getelementptr inbounds float, float* %arrayptr387664, i64 %313
  store float %value_phi332, float* %576, align 4
  %577 = fsub float %value_phi377, %value_phi376
  %578 = fcmp une float %577, 0.000000e+00
  br i1 %578, label %L980, label %L1056

oob439:                                           ; preds = %L1005
  %errorbox440 = alloca i64, align 8
  store i64 %503, i64* %errorbox440, align 8
  call void @ijl_bounds_error_ints({}* %getfield435, i64* nonnull %errorbox440, i64 1)
  unreachable

idxend441:                                        ; preds = %L1005
  %579 = bitcast {}* %getfield435 to float**
  %arrayptr443677 = load float*, float** %579, align 8
  %580 = getelementptr inbounds float, float* %arrayptr443677, i64 %502
  store float %value_phi377, float* %580, align 4
  %getfield445 = load atomic {}*, {}** %304 unordered, align 8
  %581 = bitcast {}* %getfield445 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr446 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %581, i64 0, i32 1
  %arraylen447 = load i64, i64* %arraylen_ptr446, align 8
  %inbounds448 = icmp ult i64 %502, %arraylen447
  br i1 %inbounds448, label %idxend461, label %oob449

oob449:                                           ; preds = %idxend441
  %errorbox450 = alloca i64, align 8
  store i64 %503, i64* %errorbox450, align 8
  call void @ijl_bounds_error_ints({}* %getfield445, i64* nonnull %errorbox450, i64 1)
  unreachable

idxend461:                                        ; preds = %idxend441
  %582 = bitcast {}* %getfield445 to i64**
  %arrayptr453678 = load i64*, i64** %582, align 8
  %583 = getelementptr inbounds i64, i64* %arrayptr453678, i64 %502
  store i64 %arrayref288, i64* %583, align 8
  store i64 %503, i64* %497, align 8
  br label %L1019
}
