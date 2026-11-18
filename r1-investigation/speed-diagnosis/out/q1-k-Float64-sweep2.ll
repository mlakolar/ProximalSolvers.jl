define double @"julia__sweep!_1230"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(80) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(56) %3, i8 zeroext %4, [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* nocapture noundef nonnull readonly align 8 dereferenceable(40) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1858 = alloca [5 x {}*], align 16
  %gcframe1858.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1858 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct83 = alloca [1 x i64], align 8
  %newstruct118 = alloca [1 x i64], align 8
  %newstruct366 = alloca [1 x i64], align 8
  %newstruct399 = alloca [1 x i64], align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #14
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [5 x {}*]* %gcframe1858 to i64*
  store i64 12, i64* %9, align 16
  %10 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe1858.sub, {}*** %13, align 8
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
  br i1 %.not, label %L551, label %L12

L12:                                              ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %19, i64 8
  %22 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %22 unordered, align 8
  %23 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 2
  store {}* %getfield, {}** %23, align 16
  %24 = call nonnull {}* @"j__shuffle!_1232"({}* nonnull %getfield, i64 signext %18)
  %.not604 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not604, label %L1085, label %L30.preheader

L30.preheader:                                    ; preds = %L12
  %25 = bitcast {}* %24 to i64**
  %26 = bitcast [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5 to i64***
  %getfield121859 = load atomic i64**, i64*** %26 unordered, align 8
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
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %34 to double*
  %35 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct118, i64 0, i64 0
  %36 = getelementptr inbounds i8, i8* %29, i64 24
  %37 = bitcast i8* %36 to i64*
  %getfield_addr162 = getelementptr inbounds i8, i8* %29, i64 8
  %38 = bitcast i8* %getfield_addr162 to {}**
  %39 = and i8 %4, 1
  %.not621 = icmp eq i8 %39, 0
  br label %L30

L30:                                              ; preds = %L534, %L30.preheader
  %arrayref16945 = phi i64 [ %arrayref16944, %L534 ], [ undef, %L30.preheader ]
  %value_phi5 = phi i64 [ %316, %L534 ], [ 1, %L30.preheader ]
  %value_phi7 = phi double [ %315, %L534 ], [ 0.000000e+00, %L30.preheader ]
  %40 = add nsw i64 %value_phi5, -1
  %arrayptr606 = load i64*, i64** %25, align 8
  %41 = getelementptr inbounds i64, i64* %arrayptr606, i64 %40
  %arrayref = load i64, i64* %41, align 8
  %42 = add i64 %arrayref, -1
  %43 = add i64 %42, %unbox13
  %arrayptr15607 = load i64*, i64** %getfield121859, align 8
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
  %54 = bitcast {}* %getfield20 to double**
  %arrayptr37611 = load double*, double** %54, align 8
  %55 = bitcast {}* %getfield22 to double**
  %arrayptr40612 = load double*, double** %55, align 8
  %min.iters.check1530 = icmp ult i64 %arraylen250, 8
  br i1 %min.iters.check1530, label %scalar.ph1529, label %vector.ph1531

vector.ph1531:                                    ; preds = %L81.lr.ph
  %n.vec1533 = and i64 %arraylen250, 9223372036854775800
  br label %vector.body1536

vector.body1536:                                  ; preds = %vector.body1536, %vector.ph1531
  %index1537 = phi i64 [ 0, %vector.ph1531 ], [ %index.next1548, %vector.body1536 ]
  %vec.phi1538 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %67, %vector.body1536 ]
  %vec.phi1539 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %68, %vector.body1536 ]
  %vec.phi1540 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %71, %vector.body1536 ]
  %vec.phi1541 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %72, %vector.body1536 ]
  %vec.phi1542 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %75, %vector.body1536 ]
  %vec.phi1543 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1531 ], [ %76, %vector.body1536 ]
  %56 = add i64 %53, %index1537
  %57 = getelementptr inbounds double, double* %arrayptr37611, i64 %56
  %58 = bitcast double* %57 to <4 x double>*
  %wide.load1544 = load <4 x double>, <4 x double>* %58, align 8
  %59 = getelementptr inbounds double, double* %57, i64 4
  %60 = bitcast double* %59 to <4 x double>*
  %wide.load1545 = load <4 x double>, <4 x double>* %60, align 8
  %61 = getelementptr inbounds double, double* %arrayptr40612, i64 %index1537
  %62 = bitcast double* %61 to <4 x double>*
  %wide.load1546 = load <4 x double>, <4 x double>* %62, align 8
  %63 = getelementptr inbounds double, double* %61, i64 4
  %64 = bitcast double* %63 to <4 x double>*
  %wide.load1547 = load <4 x double>, <4 x double>* %64, align 8
  %65 = fmul contract <4 x double> %wide.load1544, %wide.load1544
  %66 = fmul contract <4 x double> %wide.load1545, %wide.load1545
  %67 = fadd reassoc contract <4 x double> %vec.phi1538, %65
  %68 = fadd reassoc contract <4 x double> %vec.phi1539, %66
  %69 = fmul contract <4 x double> %wide.load1544, %wide.load1546
  %70 = fmul contract <4 x double> %wide.load1545, %wide.load1547
  %71 = fadd reassoc contract <4 x double> %vec.phi1540, %69
  %72 = fadd reassoc contract <4 x double> %vec.phi1541, %70
  %73 = fmul contract <4 x double> %wide.load1546, %wide.load1546
  %74 = fmul contract <4 x double> %wide.load1547, %wide.load1547
  %75 = fadd reassoc contract <4 x double> %vec.phi1542, %73
  %76 = fadd reassoc contract <4 x double> %vec.phi1543, %74
  %index.next1548 = add nuw i64 %index1537, 8
  %77 = icmp eq i64 %index.next1548, %n.vec1533
  br i1 %77, label %middle.block1528, label %vector.body1536

middle.block1528:                                 ; preds = %vector.body1536
  %bin.rdx1553 = fadd reassoc contract <4 x double> %76, %75
  %78 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1553)
  %bin.rdx1551 = fadd reassoc contract <4 x double> %72, %71
  %79 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1551)
  %bin.rdx1549 = fadd reassoc contract <4 x double> %68, %67
  %80 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1549)
  %cmp.n1535 = icmp eq i64 %arraylen250, %n.vec1533
  br i1 %cmp.n1535, label %L151, label %scalar.ph1529

scalar.ph1529:                                    ; preds = %middle.block1528, %L81.lr.ph
  %bc.resume.val1534 = phi i64 [ %n.vec1533, %middle.block1528 ], [ 0, %L81.lr.ph ]
  %bc.merge.rdx1550 = phi double [ %80, %middle.block1528 ], [ 0.000000e+00, %L81.lr.ph ]
  %bc.merge.rdx1552 = phi double [ %79, %middle.block1528 ], [ 0.000000e+00, %L81.lr.ph ]
  %bc.merge.rdx1554 = phi double [ %78, %middle.block1528 ], [ 0.000000e+00, %L81.lr.ph ]
  br label %L81

L81:                                              ; preds = %L81, %scalar.ph1529
  %value_phi35867 = phi double [ %bc.merge.rdx1550, %scalar.ph1529 ], [ %85, %L81 ]
  %value_phi34866 = phi i64 [ %bc.resume.val1534, %scalar.ph1529 ], [ %90, %L81 ]
  %value_phi33865 = phi double [ %bc.merge.rdx1552, %scalar.ph1529 ], [ %87, %L81 ]
  %value_phi32864 = phi double [ %bc.merge.rdx1554, %scalar.ph1529 ], [ %89, %L81 ]
  %81 = add i64 %53, %value_phi34866
  %82 = getelementptr inbounds double, double* %arrayptr37611, i64 %81
  %arrayref38 = load double, double* %82, align 8
  %83 = getelementptr inbounds double, double* %arrayptr40612, i64 %value_phi34866
  %arrayref41 = load double, double* %83, align 8
  %84 = fmul contract double %arrayref38, %arrayref38
  %85 = fadd reassoc contract double %value_phi35867, %84
  %86 = fmul contract double %arrayref38, %arrayref41
  %87 = fadd reassoc contract double %value_phi33865, %86
  %88 = fmul contract double %arrayref41, %arrayref41
  %89 = fadd reassoc contract double %value_phi32864, %88
  %90 = add nuw nsw i64 %value_phi34866, 1
  %exitcond.not = icmp eq i64 %90, %arraylen250
  br i1 %exitcond.not, label %L151, label %L81

L110:                                             ; preds = %idxend
  br i1 %.not645, label %L151, label %L123.lr.ph

L123.lr.ph:                                       ; preds = %L110
  %91 = bitcast {}* %getfield20 to {}**
  %arraysize_ptr256 = getelementptr inbounds {}*, {}** %91, i64 3
  %92 = bitcast {}** %arraysize_ptr256 to i64*
  %arraysize257 = load i64, i64* %92, align 8
  %93 = mul i64 %arraysize257, %49
  %94 = bitcast {}* %getfield20 to double**
  %arrayptr260647 = load double*, double** %94, align 8
  %95 = bitcast {}* %getfield22 to double**
  %arrayptr263648 = load double*, double** %95, align 8
  %min.iters.check1507 = icmp ult i64 %arraylen250, 8
  br i1 %min.iters.check1507, label %scalar.ph1506, label %vector.ph1508

vector.ph1508:                                    ; preds = %L123.lr.ph
  %n.vec1510 = and i64 %arraylen250, 9223372036854775800
  br label %vector.body1513

vector.body1513:                                  ; preds = %vector.body1513, %vector.ph1508
  %index1514 = phi i64 [ 0, %vector.ph1508 ], [ %index.next1523, %vector.body1513 ]
  %vec.phi1515 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1508 ], [ %107, %vector.body1513 ]
  %vec.phi1516 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1508 ], [ %108, %vector.body1513 ]
  %vec.phi1517 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1508 ], [ %111, %vector.body1513 ]
  %vec.phi1518 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1508 ], [ %112, %vector.body1513 ]
  %96 = add i64 %93, %index1514
  %97 = getelementptr inbounds double, double* %arrayptr260647, i64 %96
  %98 = bitcast double* %97 to <4 x double>*
  %wide.load1519 = load <4 x double>, <4 x double>* %98, align 8
  %99 = getelementptr inbounds double, double* %97, i64 4
  %100 = bitcast double* %99 to <4 x double>*
  %wide.load1520 = load <4 x double>, <4 x double>* %100, align 8
  %101 = getelementptr inbounds double, double* %arrayptr263648, i64 %index1514
  %102 = bitcast double* %101 to <4 x double>*
  %wide.load1521 = load <4 x double>, <4 x double>* %102, align 8
  %103 = getelementptr inbounds double, double* %101, i64 4
  %104 = bitcast double* %103 to <4 x double>*
  %wide.load1522 = load <4 x double>, <4 x double>* %104, align 8
  %105 = fmul contract <4 x double> %wide.load1519, %wide.load1521
  %106 = fmul contract <4 x double> %wide.load1520, %wide.load1522
  %107 = fadd reassoc contract <4 x double> %vec.phi1515, %105
  %108 = fadd reassoc contract <4 x double> %vec.phi1516, %106
  %109 = fmul contract <4 x double> %wide.load1521, %wide.load1521
  %110 = fmul contract <4 x double> %wide.load1522, %wide.load1522
  %111 = fadd reassoc contract <4 x double> %vec.phi1517, %109
  %112 = fadd reassoc contract <4 x double> %vec.phi1518, %110
  %index.next1523 = add nuw i64 %index1514, 8
  %113 = icmp eq i64 %index.next1523, %n.vec1510
  br i1 %113, label %middle.block1505, label %vector.body1513

middle.block1505:                                 ; preds = %vector.body1513
  %bin.rdx1526 = fadd reassoc contract <4 x double> %112, %111
  %114 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1526)
  %bin.rdx1524 = fadd reassoc contract <4 x double> %108, %107
  %115 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1524)
  %cmp.n1512 = icmp eq i64 %arraylen250, %n.vec1510
  br i1 %cmp.n1512, label %L151, label %scalar.ph1506

scalar.ph1506:                                    ; preds = %middle.block1505, %L123.lr.ph
  %bc.resume.val1511 = phi i64 [ %n.vec1510, %middle.block1505 ], [ 0, %L123.lr.ph ]
  %bc.merge.rdx1525 = phi double [ %115, %middle.block1505 ], [ 0.000000e+00, %L123.lr.ph ]
  %bc.merge.rdx1527 = phi double [ %114, %middle.block1505 ], [ 0.000000e+00, %L123.lr.ph ]
  br label %L123

L123:                                             ; preds = %L123, %scalar.ph1506
  %value_phi255873 = phi i64 [ %bc.resume.val1511, %scalar.ph1506 ], [ %123, %L123 ]
  %value_phi254872 = phi double [ %bc.merge.rdx1525, %scalar.ph1506 ], [ %120, %L123 ]
  %value_phi253871 = phi double [ %bc.merge.rdx1527, %scalar.ph1506 ], [ %122, %L123 ]
  %116 = add i64 %93, %value_phi255873
  %117 = getelementptr inbounds double, double* %arrayptr260647, i64 %116
  %arrayref261 = load double, double* %117, align 8
  %118 = getelementptr inbounds double, double* %arrayptr263648, i64 %value_phi255873
  %arrayref264 = load double, double* %118, align 8
  %119 = fmul contract double %arrayref261, %arrayref264
  %120 = fadd reassoc contract double %value_phi254872, %119
  %121 = fmul contract double %arrayref264, %arrayref264
  %122 = fadd reassoc contract double %value_phi253871, %121
  %123 = add nuw nsw i64 %value_phi255873, 1
  %exitcond1047.not = icmp eq i64 %123, %arraylen250
  br i1 %exitcond1047.not, label %L151, label %L123

L151:                                             ; preds = %L123, %middle.block1505, %L110, %L81, %middle.block1528, %L67
  %value_phi48 = phi double [ 0.000000e+00, %L67 ], [ 0.000000e+00, %L110 ], [ %114, %middle.block1505 ], [ %78, %middle.block1528 ], [ %122, %L123 ], [ %89, %L81 ]
  %value_phi49 = phi double [ 0.000000e+00, %L67 ], [ 0.000000e+00, %L110 ], [ %115, %middle.block1505 ], [ %79, %middle.block1528 ], [ %120, %L123 ], [ %87, %L81 ]
  %value_phi50 = phi double [ 0.000000e+00, %L67 ], [ %arrayref27, %L110 ], [ %arrayref27, %middle.block1505 ], [ %80, %middle.block1528 ], [ %arrayref27, %L123 ], [ %85, %L81 ]
  %124 = fsub double %value_phi48, %value_phi48
  %125 = fcmp uno double %124, 0.000000e+00
  br i1 %125, label %L156, label %L158

L156:                                             ; preds = %L151
  %126 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %126, align 8
  %127 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 4
  store {}* %getfield18, {}** %127, align 16
  store {}* %getfield22, {}** %23, align 16
  call void @j__check_residual_1241({}* nonnull %getfield22, i64 signext %arrayref16)
  br label %L158

L158:                                             ; preds = %L156, %L151
  %128 = fcmp une double %value_phi50, 0.000000e+00
  br i1 %128, label %L199, label %L160

L160:                                             ; preds = %L158
  %getfield52 = load atomic {}*, {}** %45 unordered, align 8
  %129 = bitcast {}* %getfield52 to {}**
  %arraysize_ptr53 = getelementptr inbounds {}*, {}** %129, i64 3
  %130 = bitcast {}** %arraysize_ptr53 to i64*
  %arraysize54 = load i64, i64* %130, align 8
  %.not613.not = icmp eq i64 %arraysize54, 0
  br i1 %.not613.not, label %L199, label %L173.preheader

L173.preheader:                                   ; preds = %L160
  %arraysize_ptr67 = getelementptr inbounds {}*, {}** %129, i64 4
  %131 = bitcast {}** %arraysize_ptr67 to i64*
  %arraysize68 = load i64, i64* %131, align 8
  %inbounds69 = icmp ult i64 %49, %arraysize68
  %132 = mul i64 %arraysize54, %49
  %133 = bitcast {}* %getfield52 to double**
  %arrayptr74615 = load double*, double** %133, align 8
  %inbounds69.fr = freeze i1 %inbounds69
  br i1 %inbounds69.fr, label %ib.us, label %oob70

ib.us:                                            ; preds = %L179.us, %L173.preheader
  %value_phi59.us = phi i64 [ %138, %L179.us ], [ 1, %L173.preheader ]
  %134 = add nsw i64 %value_phi59.us, -1
  %135 = add i64 %132, %134
  %136 = getelementptr inbounds double, double* %arrayptr74615, i64 %135
  %arrayref75.us = load double, double* %136, align 8
  %137 = fcmp une double %arrayref75.us, 0.000000e+00
  br i1 %137, label %L195.split.us, label %L179.us

L179.us:                                          ; preds = %ib.us
  %138 = add nuw nsw i64 %value_phi59.us, 1
  %139 = icmp ult i64 %value_phi59.us, %arraysize54
  br i1 %139, label %ib.us, label %L199

L195.split.us:                                    ; preds = %ib.us
  store {}* inttoptr (i64 135794558905424 to {}*), {}** %6, align 8
  %140 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %140)
  unreachable

L199:                                             ; preds = %L179.us, %L160, %L158
  %141 = fsub double %value_phi50, %value_phi50
  %142 = fcmp uno double %141, 0.000000e+00
  br i1 %142, label %L512, label %L204

L204:                                             ; preds = %L199
  %getfield82 = load atomic {}*, {}** %30 unordered, align 8
  %143 = bitcast {}* %getfield82 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr84 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %143, i64 0, i32 1
  %arraylen85 = load i64, i64* %arraylen_ptr84, align 8
  %.not617 = icmp ult i64 %49, %arraylen85
  br i1 %.not617, label %L218, label %L215

L215:                                             ; preds = %L204
  store i64 %arrayref16, i64* %31, align 8
  store {}* %getfield82, {}** %23, align 16
  call void @j_throw_boundserror_1236({}* nonnull %getfield82, [1 x i64]* nocapture readonly %newstruct83) #3
  unreachable

L218:                                             ; preds = %L204
  %144 = bitcast {}* %getfield82 to i64**
  %arrayptr90618 = load i64*, i64** %144, align 8
  %145 = getelementptr inbounds i64, i64* %arrayptr90618, i64 %49
  %arrayref91 = load i64, i64* %145, align 8
  %.not619 = icmp eq i64 %arrayref91, 0
  br i1 %.not619, label %L228, label %L223

L223:                                             ; preds = %L218
  %146 = bitcast {}* %0 to double***
  %getfield2411860 = load atomic double**, double*** %146 unordered, align 8
  %147 = add i64 %arrayref91, -1
  %arrayptr243644 = load double*, double** %getfield2411860, align 8
  %148 = getelementptr inbounds double, double* %arrayptr243644, i64 %147
  %arrayref244 = load double, double* %148, align 8
  br label %L228

L228:                                             ; preds = %L223, %L218
  %value_phi92 = phi double [ %arrayref244, %L223 ], [ 0.000000e+00, %L218 ]
  br i1 %128, label %L232, label %L230

L230:                                             ; preds = %L228
  %149 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %149, align 8
  %150 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 4
  store {}* %getfield18, {}** %150, align 16
  %151 = call double @j__coordinate_minimizer_1234({ double }* nocapture nonnull readonly %2, double %value_phi92, i64 signext %arrayref16)
  br label %L430

L232:                                             ; preds = %L228
  %getfield184 = load atomic {}*, {}** %28 unordered, align 8
  %152 = bitcast {}* %getfield184 to i8*
  %getfield_addr185 = getelementptr inbounds i8, i8* %152, i64 24
  %153 = bitcast i8* %getfield_addr185 to {}**
  %getfield186 = load atomic {}*, {}** %153 unordered, align 8
  %154 = bitcast {}* %getfield186 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr187 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %154, i64 0, i32 1
  %arraylen188 = load i64, i64* %arraylen_ptr187, align 8
  %155 = sitofp i64 %arraylen188 to double
  %156 = fmul double %155, 0x350000000000000
  %157 = fcmp ole double %156, %value_phi50
  %158 = fcmp ord double %124, 0.000000e+00
  %159 = fcmp ole double %156, %value_phi48
  %160 = and i1 %158, %159
  %161 = and i1 %157, %160
  br i1 %161, label %L251, label %L427

L251:                                             ; preds = %L232
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %162 = fcmp uge double %value_phi50, 0.000000e+00
  br i1 %162, label %L257, label %L255

L255:                                             ; preds = %L251
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %value_phi50) #3
  unreachable

L257:                                             ; preds = %L251
  %163 = call double @llvm.sqrt.f64(double %value_phi50)
  %164 = fcmp ugt double %163, %aggregate_load_box.sroa.0.0.copyload
  br i1 %164, label %L262, label %L430

L262:                                             ; preds = %L257
  %165 = fdiv double %value_phi49, %value_phi50
  %166 = fadd double %165, %value_phi92
  %167 = fmul double %value_phi49, %165
  %168 = fsub double %value_phi48, %167
  %169 = fmul double %value_phi48, 6.250000e-02
  %170 = fcmp uge double %168, %169
  br i1 %170, label %L317, label %L269

L269:                                             ; preds = %L262
  %.not635 = icmp eq i64 %arraylen188, 0
  br i1 %.not635, label %L306, label %L283.lr.ph

L283.lr.ph:                                       ; preds = %L269
  %171 = bitcast {}* %getfield184 to {}**
  %getfield193 = load atomic {}*, {}** %171 unordered, align 8
  %172 = bitcast {}* %getfield186 to double**
  %arrayptr203637 = load double*, double** %172, align 8
  %173 = bitcast {}* %getfield193 to {}**
  %arraysize_ptr205 = getelementptr inbounds {}*, {}** %173, i64 3
  %174 = bitcast {}** %arraysize_ptr205 to i64*
  %arraysize206 = load i64, i64* %174, align 8
  %175 = mul i64 %arraysize206, %49
  %176 = bitcast {}* %getfield193 to double**
  %arrayptr209638 = load double*, double** %176, align 8
  %min.iters.check1475 = icmp ult i64 %arraylen188, 16
  br i1 %min.iters.check1475, label %scalar.ph1474, label %vector.ph1476

vector.ph1476:                                    ; preds = %L283.lr.ph
  %n.vec1478 = and i64 %arraylen188, 9223372036854775792
  %broadcast.splatinsert1494 = insertelement <4 x double> poison, double %165, i64 0
  %broadcast.splat1495 = shufflevector <4 x double> %broadcast.splatinsert1494, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1481

vector.body1481:                                  ; preds = %vector.body1481, %vector.ph1476
  %index1482 = phi i64 [ 0, %vector.ph1476 ], [ %index.next1502, %vector.body1481 ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1476 ], [ %206, %vector.body1481 ]
  %vec.phi1483 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1476 ], [ %207, %vector.body1481 ]
  %vec.phi1484 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1476 ], [ %208, %vector.body1481 ]
  %vec.phi1485 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1476 ], [ %209, %vector.body1481 ]
  %177 = getelementptr inbounds double, double* %arrayptr203637, i64 %index1482
  %178 = bitcast double* %177 to <4 x double>*
  %wide.load1486 = load <4 x double>, <4 x double>* %178, align 8
  %179 = getelementptr inbounds double, double* %177, i64 4
  %180 = bitcast double* %179 to <4 x double>*
  %wide.load1487 = load <4 x double>, <4 x double>* %180, align 8
  %181 = getelementptr inbounds double, double* %177, i64 8
  %182 = bitcast double* %181 to <4 x double>*
  %wide.load1488 = load <4 x double>, <4 x double>* %182, align 8
  %183 = getelementptr inbounds double, double* %177, i64 12
  %184 = bitcast double* %183 to <4 x double>*
  %wide.load1489 = load <4 x double>, <4 x double>* %184, align 8
  %185 = add i64 %175, %index1482
  %186 = getelementptr inbounds double, double* %arrayptr209638, i64 %185
  %187 = bitcast double* %186 to <4 x double>*
  %wide.load1490 = load <4 x double>, <4 x double>* %187, align 8
  %188 = getelementptr inbounds double, double* %186, i64 4
  %189 = bitcast double* %188 to <4 x double>*
  %wide.load1491 = load <4 x double>, <4 x double>* %189, align 8
  %190 = getelementptr inbounds double, double* %186, i64 8
  %191 = bitcast double* %190 to <4 x double>*
  %wide.load1492 = load <4 x double>, <4 x double>* %191, align 8
  %192 = getelementptr inbounds double, double* %186, i64 12
  %193 = bitcast double* %192 to <4 x double>*
  %wide.load1493 = load <4 x double>, <4 x double>* %193, align 8
  %194 = fmul <4 x double> %broadcast.splat1495, %wide.load1490
  %195 = fmul <4 x double> %broadcast.splat1495, %wide.load1491
  %196 = fmul <4 x double> %broadcast.splat1495, %wide.load1492
  %197 = fmul <4 x double> %broadcast.splat1495, %wide.load1493
  %198 = fsub <4 x double> %wide.load1486, %194
  %199 = fsub <4 x double> %wide.load1487, %195
  %200 = fsub <4 x double> %wide.load1488, %196
  %201 = fsub <4 x double> %wide.load1489, %197
  %202 = fmul contract <4 x double> %198, %198
  %203 = fmul contract <4 x double> %199, %199
  %204 = fmul contract <4 x double> %200, %200
  %205 = fmul contract <4 x double> %201, %201
  %206 = fadd reassoc contract <4 x double> %vec.phi, %202
  %207 = fadd reassoc contract <4 x double> %vec.phi1483, %203
  %208 = fadd reassoc contract <4 x double> %vec.phi1484, %204
  %209 = fadd reassoc contract <4 x double> %vec.phi1485, %205
  %index.next1502 = add nuw i64 %index1482, 16
  %210 = icmp eq i64 %index.next1502, %n.vec1478
  br i1 %210, label %middle.block1473, label %vector.body1481

middle.block1473:                                 ; preds = %vector.body1481
  %bin.rdx = fadd reassoc contract <4 x double> %207, %206
  %bin.rdx1503 = fadd reassoc contract <4 x double> %208, %bin.rdx
  %bin.rdx1504 = fadd reassoc contract <4 x double> %209, %bin.rdx1503
  %211 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1504)
  %cmp.n1480 = icmp eq i64 %arraylen188, %n.vec1478
  br i1 %cmp.n1480, label %L306, label %scalar.ph1474

scalar.ph1474:                                    ; preds = %middle.block1473, %L283.lr.ph
  %bc.resume.val1479 = phi i64 [ %n.vec1478, %middle.block1473 ], [ 0, %L283.lr.ph ]
  %bc.merge.rdx = phi double [ %211, %middle.block1473 ], [ 0.000000e+00, %L283.lr.ph ]
  br label %L283

L283:                                             ; preds = %L283, %scalar.ph1474
  %value_phi201878 = phi i64 [ %bc.resume.val1479, %scalar.ph1474 ], [ %219, %L283 ]
  %value_phi200877 = phi double [ %bc.merge.rdx, %scalar.ph1474 ], [ %218, %L283 ]
  %212 = getelementptr inbounds double, double* %arrayptr203637, i64 %value_phi201878
  %arrayref204 = load double, double* %212, align 8
  %213 = add i64 %175, %value_phi201878
  %214 = getelementptr inbounds double, double* %arrayptr209638, i64 %213
  %arrayref210 = load double, double* %214, align 8
  %215 = fmul double %165, %arrayref210
  %216 = fsub double %arrayref204, %215
  %217 = fmul contract double %216, %216
  %218 = fadd reassoc contract double %value_phi200877, %217
  %219 = add nuw nsw i64 %value_phi201878, 1
  %exitcond1048.not = icmp eq i64 %219, %arraylen188
  br i1 %exitcond1048.not, label %L306, label %L283

L306:                                             ; preds = %L283, %middle.block1473, %L269
  %value_phi212 = phi double [ 0.000000e+00, %L269 ], [ %211, %middle.block1473 ], [ %218, %L283 ]
  %220 = fsub double %value_phi212, %value_phi212
  %221 = fcmp uno double %220, 0.000000e+00
  %222 = fcmp ugt double %156, %value_phi212
  %223 = or i1 %222, %221
  br i1 %223, label %L315, label %L317

L315:                                             ; preds = %L306
  %224 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %224, align 8
  %225 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 4
  store {}* %getfield18, {}** %225, align 16
  %226 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi92, i64 signext %arrayref16)
  br label %L430

L317:                                             ; preds = %L306, %L262
  %value_phi214 = phi double [ %168, %L262 ], [ %value_phi212, %L306 ]
  %227 = fcmp uge double %value_phi214, 0.000000e+00
  br i1 %227, label %L322, label %L320

L320:                                             ; preds = %L317
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %value_phi214) #3
  unreachable

L322:                                             ; preds = %L317
  %228 = call double @llvm.sqrt.f64(double %value_phi214)
  %229 = fsub double %163, %aggregate_load_box.sroa.0.0.copyload
  %230 = fcmp uge double %229, 0.000000e+00
  br i1 %230, label %L329, label %L327

L327:                                             ; preds = %L322
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %229) #3
  unreachable

L329:                                             ; preds = %L322
  %231 = fadd double %163, %aggregate_load_box.sroa.0.0.copyload
  %232 = fcmp uge double %231, 0.000000e+00
  br i1 %232, label %L336, label %L334

L334:                                             ; preds = %L329
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %231) #3
  unreachable

L336:                                             ; preds = %L329
  %233 = call double @llvm.sqrt.f64(double %229)
  %234 = call double @llvm.sqrt.f64(double %231)
  %235 = fmul double %233, %234
  %236 = fmul double %163, %235
  %237 = fdiv double %228, %236
  %238 = fmul double %aggregate_load_box.sroa.0.0.copyload, %237
  %239 = fcmp oge double %236, 0x10000000000000
  %240 = fcmp oge double %237, 0x10000000000000
  %241 = fcmp ole double %237, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %240, %241
  %242 = and i1 %239, %narrow
  %243 = fcmp oge double %238, 0x10000000000000
  %244 = fcmp ole double %238, 0x7FEFFFFFFFFFFFFF
  %narrow639 = and i1 %243, %244
  %245 = and i1 %242, %narrow639
  br i1 %245, label %L370, label %L425

L370:                                             ; preds = %L336
  %246 = fneg double %238
  %.inv641 = fcmp ogt double %166, %246
  %247 = select i1 %.inv641, double %166, double %246
  %.inv642 = fcmp olt double %247, %238
  %248 = select i1 %.inv642, double %247, double %238
  %249 = fsub double %166, %248
  %250 = fadd double %249, 0.000000e+00
  br label %L430

L425:                                             ; preds = %L336
  %251 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %251, align 8
  %252 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 4
  store {}* %getfield18, {}** %252, align 16
  %253 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi92, i64 signext %arrayref16)
  br label %L430

L427:                                             ; preds = %L232
  %254 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %254, align 8
  %255 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 4
  store {}* %getfield18, {}** %255, align 16
  %256 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi92, i64 signext %arrayref16)
  br label %L430

L430:                                             ; preds = %L427, %L425, %L370, %L315, %L257, %L230
  %value_phi93 = phi double [ %151, %L230 ], [ %226, %L315 ], [ %253, %L425 ], [ %256, %L427 ], [ 0.000000e+00, %L257 ], [ %250, %L370 ]
  %getfield95 = load atomic {}*, {}** %48 unordered, align 8
  %257 = bitcast {}* %getfield95 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr96 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %257, i64 0, i32 1
  %arraylen97 = load i64, i64* %arraylen_ptr96, align 8
  %inbounds98 = icmp ult i64 %49, %arraylen97
  br i1 %inbounds98, label %idxend101, label %oob99

L438:                                             ; preds = %idxend101
  %getfield117 = load atomic {}*, {}** %30 unordered, align 8
  %258 = bitcast {}* %getfield117 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr119 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %258, i64 0, i32 1
  %arraylen120 = load i64, i64* %arraylen_ptr119, align 8
  %.not623 = icmp ult i64 %49, %arraylen120
  br i1 %.not623, label %L452, label %L449

L449:                                             ; preds = %L438
  store i64 %arrayref16, i64* %35, align 8
  store {}* %getfield117, {}** %23, align 16
  call void @j_throw_boundserror_1236({}* nonnull %getfield117, [1 x i64]* nocapture readonly %newstruct118) #3
  unreachable

L452:                                             ; preds = %L438
  %259 = bitcast {}* %getfield117 to i64**
  %arrayptr125624 = load i64*, i64** %259, align 8
  %260 = getelementptr inbounds i64, i64* %arrayptr125624, i64 %49
  %arrayref126 = load i64, i64* %260, align 8
  %.not625 = icmp eq i64 %arrayref126, 0
  br i1 %.not625, label %L460, label %L457

L457:                                             ; preds = %L452
  %261 = bitcast {}* %0 to double***
  %getfield1281861 = load atomic double**, double*** %261 unordered, align 8
  %262 = add i64 %arrayref126, -1
  %arrayptr130626 = load double*, double** %getfield1281861, align 8
  %263 = getelementptr inbounds double, double* %arrayptr130626, i64 %262
  store double %value_phi93, double* %263, align 8
  br label %L477

L460:                                             ; preds = %L452
  %264 = fcmp oeq double %value_phi93, 0.000000e+00
  br i1 %264, label %L477, label %L463

L463:                                             ; preds = %L460
  %265 = load i64, i64* %37, align 8
  %266 = add i64 %265, 1
  store i64 %266, i64* %37, align 8
  %getfield153 = load atomic {}*, {}** %32 unordered, align 8
  %267 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %267, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %265, %arraylen155
  br i1 %inbounds156, label %idxend159, label %oob157

L477:                                             ; preds = %idxend179, %L460, %L457
  %getfield132 = load atomic {}*, {}** %47 unordered, align 8
  %268 = bitcast {}* %getfield132 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr135 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %268, i64 0, i32 1
  %arraylen136 = load i64, i64* %arraylen_ptr135, align 8
  %.not627 = icmp eq i64 %arraylen136, 0
  br i1 %.not627, label %L514, label %L490.lr.ph

L490.lr.ph:                                       ; preds = %L477
  %getfield134 = load atomic {}*, {}** %45 unordered, align 8
  %269 = bitcast {}* %getfield132 to double**
  %arrayptr141629 = load double*, double** %269, align 8
  %270 = bitcast {}* %getfield134 to {}**
  %arraysize_ptr143 = getelementptr inbounds {}*, {}** %270, i64 3
  %271 = bitcast {}** %arraysize_ptr143 to i64*
  %arraysize144 = load i64, i64* %271, align 8
  %272 = mul i64 %arraysize144, %49
  %273 = bitcast {}* %getfield134 to double**
  %arrayptr147630 = load double*, double** %273, align 8
  %min.iters.check = icmp ult i64 %arraylen136, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L490.lr.ph
  %scevgep = getelementptr double, double* %arrayptr141629, i64 %arraylen136
  %scevgep1456 = getelementptr double, double* %arrayptr147630, i64 %272
  %274 = add i64 %arraylen136, %272
  %scevgep1458 = getelementptr double, double* %arrayptr147630, i64 %274
  %bound0 = icmp ult double* %arrayptr141629, %scevgep1458
  %bound1 = icmp ult double* %scevgep1456, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen136, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %613, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %275 = getelementptr inbounds double, double* %arrayptr141629, i64 %index
  %276 = bitcast double* %275 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %276, align 8
  %277 = getelementptr inbounds double, double* %275, i64 4
  %278 = bitcast double* %277 to <4 x double>*
  %wide.load1460 = load <4 x double>, <4 x double>* %278, align 8
  %279 = getelementptr inbounds double, double* %275, i64 8
  %280 = bitcast double* %279 to <4 x double>*
  %wide.load1461 = load <4 x double>, <4 x double>* %280, align 8
  %281 = getelementptr inbounds double, double* %275, i64 12
  %282 = bitcast double* %281 to <4 x double>*
  %wide.load1462 = load <4 x double>, <4 x double>* %282, align 8
  %283 = add i64 %272, %index
  %284 = getelementptr inbounds double, double* %arrayptr147630, i64 %283
  %285 = bitcast double* %284 to <4 x double>*
  %wide.load1463 = load <4 x double>, <4 x double>* %285, align 8
  %286 = getelementptr inbounds double, double* %284, i64 4
  %287 = bitcast double* %286 to <4 x double>*
  %wide.load1464 = load <4 x double>, <4 x double>* %287, align 8
  %288 = getelementptr inbounds double, double* %284, i64 8
  %289 = bitcast double* %288 to <4 x double>*
  %wide.load1465 = load <4 x double>, <4 x double>* %289, align 8
  %290 = getelementptr inbounds double, double* %284, i64 12
  %291 = bitcast double* %290 to <4 x double>*
  %wide.load1466 = load <4 x double>, <4 x double>* %291, align 8
  %292 = fmul <4 x double> %broadcast.splat, %wide.load1463
  %293 = fmul <4 x double> %broadcast.splat, %wide.load1464
  %294 = fmul <4 x double> %broadcast.splat, %wide.load1465
  %295 = fmul <4 x double> %broadcast.splat, %wide.load1466
  %296 = fsub <4 x double> %wide.load, %292
  %297 = fsub <4 x double> %wide.load1460, %293
  %298 = fsub <4 x double> %wide.load1461, %294
  %299 = fsub <4 x double> %wide.load1462, %295
  store <4 x double> %296, <4 x double>* %276, align 8
  store <4 x double> %297, <4 x double>* %278, align 8
  store <4 x double> %298, <4 x double>* %280, align 8
  store <4 x double> %299, <4 x double>* %282, align 8
  %index.next = add nuw i64 %index, 16
  %300 = icmp eq i64 %index.next, %n.vec
  br i1 %300, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen136, %n.vec
  br i1 %cmp.n, label %L514, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L490.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L490.lr.ph ], [ 0, %vector.memcheck ]
  br label %L490

L490:                                             ; preds = %L490, %scalar.ph
  %value_phi139881 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %306, %L490 ]
  %301 = getelementptr inbounds double, double* %arrayptr141629, i64 %value_phi139881
  %arrayref142 = load double, double* %301, align 8
  %302 = add i64 %272, %value_phi139881
  %303 = getelementptr inbounds double, double* %arrayptr147630, i64 %302
  %arrayref148 = load double, double* %303, align 8
  %304 = fmul double %613, %arrayref148
  %305 = fsub double %arrayref142, %304
  store double %305, double* %301, align 8
  %306 = add nuw nsw i64 %value_phi139881, 1
  %exitcond1049.not = icmp eq i64 %306, %arraylen136
  br i1 %exitcond1049.not, label %L514, label %L490

L512:                                             ; preds = %L199
  call void @j__refuse_curvature_1240(i64 signext %arrayref16) #3
  unreachable

L514:                                             ; preds = %idxend101, %L490, %middle.block, %L477
  %arrayref16944 = phi i64 [ %arrayref16, %L477 ], [ %arrayref16945, %idxend101 ], [ %arrayref16, %middle.block ], [ %arrayref16, %L490 ]
  %307 = call double @llvm.fabs.f64(double %613)
  %308 = fcmp oeq double %613, 0.000000e+00
  %or.cond = select i1 %.not621, i1 true, i1 %308
  br i1 %or.cond, label %L525, label %L520

L520:                                             ; preds = %L514
  %getfield106 = load atomic {}*, {}** %28 unordered, align 8
  %309 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %24, {}** %309, align 8
  store {}* %getfield106, {}** %23, align 16
  %310 = call double @j_coordinate_scale_1235({}* nonnull %getfield106, {}* nonnull %0, i64 signext %arrayref16)
  %311 = fmul double %307, %310
  br label %L525

L525:                                             ; preds = %L520, %L514
  %value_phi107 = phi double [ %311, %L520 ], [ %307, %L514 ]
  %312 = fsub double %value_phi107, %value_phi107
  %313 = fcmp uno double %312, 0.000000e+00
  br i1 %313, label %L531, label %L534

L531:                                             ; preds = %L525
  store {}* inttoptr (i64 135794567639056 to {}*), {}** %6, align 8
  %314 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %314)
  unreachable

L534:                                             ; preds = %L525
  %.inv = fcmp olt double %value_phi7, %value_phi107
  %315 = select i1 %.inv, double %value_phi107, double %value_phi7
  %.not622.not = icmp eq i64 %value_phi5, %18
  %316 = add nuw i64 %value_phi5, 1
  br i1 %.not622.not, label %L1085.loopexit699, label %L30

L551:                                             ; preds = %top
  %.not649 = icmp ugt i64 %16, 9223372036854775806
  br i1 %.not649, label %L1085, label %L567.preheader

L567.preheader:                                   ; preds = %L551
  %317 = bitcast [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5 to i64***
  %getfield2831862 = load atomic i64**, i64*** %317 unordered, align 8
  %318 = getelementptr inbounds [1 x { {}*, [1 x [2 x i64]], i64, i64 }], [1 x { {}*, [1 x [2 x i64]], i64, i64 }]* %5, i64 0, i64 0, i32 2
  %unbox284 = load i64, i64* %318, align 8
  %319 = bitcast {}* %1 to {}**
  %320 = bitcast {}* %0 to i8*
  %getfield_addr364 = getelementptr inbounds i8, i8* %320, i64 16
  %321 = bitcast i8* %getfield_addr364 to {}**
  %322 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct366, i64 0, i64 0
  %323 = bitcast {}* %0 to {}**
  %324 = bitcast {}* %1 to i8*
  %325 = getelementptr inbounds i8, i8* %324, i64 8
  %aggregate_load_box470.sroa.0.0..sroa_idx = bitcast i8* %325 to double*
  %326 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct399, i64 0, i64 0
  %327 = getelementptr inbounds i8, i8* %320, i64 24
  %328 = bitcast i8* %327 to i64*
  %getfield_addr443 = getelementptr inbounds i8, i8* %320, i64 8
  %329 = bitcast i8* %getfield_addr443 to {}**
  %330 = and i8 %4, 1
  %.not665 = icmp eq i8 %330, 0
  br label %L567

L567:                                             ; preds = %L1070, %L567.preheader
  %arrayref2871006 = phi i64 [ %arrayref2871005, %L1070 ], [ undef, %L567.preheader ]
  %value_phi275 = phi i64 [ %603, %L1070 ], [ 1, %L567.preheader ]
  %value_phi277 = phi double [ %602, %L1070 ], [ 0.000000e+00, %L567.preheader ]
  %331 = add nsw i64 %value_phi275, -1
  %332 = add i64 %331, %unbox284
  %arrayptr286651 = load i64*, i64** %getfield2831862, align 8
  %333 = getelementptr inbounds i64, i64* %arrayptr286651, i64 %332
  %arrayref287 = load i64, i64* %333, align 8
  %getfield289 = load atomic {}*, {}** %319 unordered, align 8
  %334 = bitcast {}* %getfield289 to {}**
  %getfield291 = load atomic {}*, {}** %334 unordered, align 8
  %335 = bitcast {}* %getfield289 to i8*
  %getfield_addr292 = getelementptr inbounds i8, i8* %335, i64 24
  %336 = bitcast i8* %getfield_addr292 to {}**
  %getfield293 = load atomic {}*, {}** %336 unordered, align 8
  %getfield_addr294 = getelementptr inbounds i8, i8* %335, i64 32
  %337 = bitcast i8* %getfield_addr294 to {}**
  %getfield295 = load atomic {}*, {}** %337 unordered, align 8
  %338 = add i64 %arrayref287, -1
  %339 = bitcast {}* %getfield295 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr296 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %339, i64 0, i32 1
  %arraylen297 = load i64, i64* %arraylen_ptr296, align 8
  %inbounds298 = icmp ult i64 %338, %arraylen297
  br i1 %inbounds298, label %idxend301, label %oob299

L603:                                             ; preds = %idxend301
  br i1 %.not691, label %L687, label %L617.lr.ph

L617.lr.ph:                                       ; preds = %L603
  %340 = bitcast {}* %getfield291 to {}**
  %arraysize_ptr313 = getelementptr inbounds {}*, {}** %340, i64 3
  %341 = bitcast {}** %arraysize_ptr313 to i64*
  %arraysize314 = load i64, i64* %341, align 8
  %342 = mul i64 %arraysize314, %338
  %343 = bitcast {}* %getfield291 to double**
  %arrayptr317655 = load double*, double** %343, align 8
  %344 = bitcast {}* %getfield293 to double**
  %arrayptr320656 = load double*, double** %344, align 8
  %min.iters.check1653 = icmp ult i64 %arraylen533, 8
  br i1 %min.iters.check1653, label %scalar.ph1652, label %vector.ph1654

vector.ph1654:                                    ; preds = %L617.lr.ph
  %n.vec1656 = and i64 %arraylen533, 9223372036854775800
  br label %vector.body1659

vector.body1659:                                  ; preds = %vector.body1659, %vector.ph1654
  %index1660 = phi i64 [ 0, %vector.ph1654 ], [ %index.next1671, %vector.body1659 ]
  %vec.phi1661 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %356, %vector.body1659 ]
  %vec.phi1662 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %357, %vector.body1659 ]
  %vec.phi1663 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %360, %vector.body1659 ]
  %vec.phi1664 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %361, %vector.body1659 ]
  %vec.phi1665 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %364, %vector.body1659 ]
  %vec.phi1666 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1654 ], [ %365, %vector.body1659 ]
  %345 = add i64 %342, %index1660
  %346 = getelementptr inbounds double, double* %arrayptr317655, i64 %345
  %347 = bitcast double* %346 to <4 x double>*
  %wide.load1667 = load <4 x double>, <4 x double>* %347, align 8
  %348 = getelementptr inbounds double, double* %346, i64 4
  %349 = bitcast double* %348 to <4 x double>*
  %wide.load1668 = load <4 x double>, <4 x double>* %349, align 8
  %350 = getelementptr inbounds double, double* %arrayptr320656, i64 %index1660
  %351 = bitcast double* %350 to <4 x double>*
  %wide.load1669 = load <4 x double>, <4 x double>* %351, align 8
  %352 = getelementptr inbounds double, double* %350, i64 4
  %353 = bitcast double* %352 to <4 x double>*
  %wide.load1670 = load <4 x double>, <4 x double>* %353, align 8
  %354 = fmul contract <4 x double> %wide.load1667, %wide.load1667
  %355 = fmul contract <4 x double> %wide.load1668, %wide.load1668
  %356 = fadd reassoc contract <4 x double> %vec.phi1661, %354
  %357 = fadd reassoc contract <4 x double> %vec.phi1662, %355
  %358 = fmul contract <4 x double> %wide.load1667, %wide.load1669
  %359 = fmul contract <4 x double> %wide.load1668, %wide.load1670
  %360 = fadd reassoc contract <4 x double> %vec.phi1663, %358
  %361 = fadd reassoc contract <4 x double> %vec.phi1664, %359
  %362 = fmul contract <4 x double> %wide.load1669, %wide.load1669
  %363 = fmul contract <4 x double> %wide.load1670, %wide.load1670
  %364 = fadd reassoc contract <4 x double> %vec.phi1665, %362
  %365 = fadd reassoc contract <4 x double> %vec.phi1666, %363
  %index.next1671 = add nuw i64 %index1660, 8
  %366 = icmp eq i64 %index.next1671, %n.vec1656
  br i1 %366, label %middle.block1651, label %vector.body1659

middle.block1651:                                 ; preds = %vector.body1659
  %bin.rdx1676 = fadd reassoc contract <4 x double> %365, %364
  %367 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1676)
  %bin.rdx1674 = fadd reassoc contract <4 x double> %361, %360
  %368 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1674)
  %bin.rdx1672 = fadd reassoc contract <4 x double> %357, %356
  %369 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1672)
  %cmp.n1658 = icmp eq i64 %arraylen533, %n.vec1656
  br i1 %cmp.n1658, label %L687, label %scalar.ph1652

scalar.ph1652:                                    ; preds = %middle.block1651, %L617.lr.ph
  %bc.resume.val1657 = phi i64 [ %n.vec1656, %middle.block1651 ], [ 0, %L617.lr.ph ]
  %bc.merge.rdx1673 = phi double [ %369, %middle.block1651 ], [ 0.000000e+00, %L617.lr.ph ]
  %bc.merge.rdx1675 = phi double [ %368, %middle.block1651 ], [ 0.000000e+00, %L617.lr.ph ]
  %bc.merge.rdx1677 = phi double [ %367, %middle.block1651 ], [ 0.000000e+00, %L617.lr.ph ]
  br label %L617

L617:                                             ; preds = %L617, %scalar.ph1652
  %value_phi312886 = phi double [ %bc.merge.rdx1673, %scalar.ph1652 ], [ %374, %L617 ]
  %value_phi311885 = phi i64 [ %bc.resume.val1657, %scalar.ph1652 ], [ %379, %L617 ]
  %value_phi310884 = phi double [ %bc.merge.rdx1675, %scalar.ph1652 ], [ %376, %L617 ]
  %value_phi309883 = phi double [ %bc.merge.rdx1677, %scalar.ph1652 ], [ %378, %L617 ]
  %370 = add i64 %342, %value_phi311885
  %371 = getelementptr inbounds double, double* %arrayptr317655, i64 %370
  %arrayref318 = load double, double* %371, align 8
  %372 = getelementptr inbounds double, double* %arrayptr320656, i64 %value_phi311885
  %arrayref321 = load double, double* %372, align 8
  %373 = fmul contract double %arrayref318, %arrayref318
  %374 = fadd reassoc contract double %value_phi312886, %373
  %375 = fmul contract double %arrayref318, %arrayref321
  %376 = fadd reassoc contract double %value_phi310884, %375
  %377 = fmul contract double %arrayref321, %arrayref321
  %378 = fadd reassoc contract double %value_phi309883, %377
  %379 = add nuw nsw i64 %value_phi311885, 1
  %exitcond1050.not = icmp eq i64 %379, %arraylen533
  br i1 %exitcond1050.not, label %L687, label %L617

L646:                                             ; preds = %idxend301
  br i1 %.not691, label %L687, label %L659.lr.ph

L659.lr.ph:                                       ; preds = %L646
  %380 = bitcast {}* %getfield291 to {}**
  %arraysize_ptr539 = getelementptr inbounds {}*, {}** %380, i64 3
  %381 = bitcast {}** %arraysize_ptr539 to i64*
  %arraysize540 = load i64, i64* %381, align 8
  %382 = mul i64 %arraysize540, %338
  %383 = bitcast {}* %getfield291 to double**
  %arrayptr543693 = load double*, double** %383, align 8
  %384 = bitcast {}* %getfield293 to double**
  %arrayptr546694 = load double*, double** %384, align 8
  %min.iters.check1630 = icmp ult i64 %arraylen533, 8
  br i1 %min.iters.check1630, label %scalar.ph1629, label %vector.ph1631

vector.ph1631:                                    ; preds = %L659.lr.ph
  %n.vec1633 = and i64 %arraylen533, 9223372036854775800
  br label %vector.body1636

vector.body1636:                                  ; preds = %vector.body1636, %vector.ph1631
  %index1637 = phi i64 [ 0, %vector.ph1631 ], [ %index.next1646, %vector.body1636 ]
  %vec.phi1638 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1631 ], [ %396, %vector.body1636 ]
  %vec.phi1639 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1631 ], [ %397, %vector.body1636 ]
  %vec.phi1640 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1631 ], [ %400, %vector.body1636 ]
  %vec.phi1641 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1631 ], [ %401, %vector.body1636 ]
  %385 = add i64 %382, %index1637
  %386 = getelementptr inbounds double, double* %arrayptr543693, i64 %385
  %387 = bitcast double* %386 to <4 x double>*
  %wide.load1642 = load <4 x double>, <4 x double>* %387, align 8
  %388 = getelementptr inbounds double, double* %386, i64 4
  %389 = bitcast double* %388 to <4 x double>*
  %wide.load1643 = load <4 x double>, <4 x double>* %389, align 8
  %390 = getelementptr inbounds double, double* %arrayptr546694, i64 %index1637
  %391 = bitcast double* %390 to <4 x double>*
  %wide.load1644 = load <4 x double>, <4 x double>* %391, align 8
  %392 = getelementptr inbounds double, double* %390, i64 4
  %393 = bitcast double* %392 to <4 x double>*
  %wide.load1645 = load <4 x double>, <4 x double>* %393, align 8
  %394 = fmul contract <4 x double> %wide.load1642, %wide.load1644
  %395 = fmul contract <4 x double> %wide.load1643, %wide.load1645
  %396 = fadd reassoc contract <4 x double> %vec.phi1638, %394
  %397 = fadd reassoc contract <4 x double> %vec.phi1639, %395
  %398 = fmul contract <4 x double> %wide.load1644, %wide.load1644
  %399 = fmul contract <4 x double> %wide.load1645, %wide.load1645
  %400 = fadd reassoc contract <4 x double> %vec.phi1640, %398
  %401 = fadd reassoc contract <4 x double> %vec.phi1641, %399
  %index.next1646 = add nuw i64 %index1637, 8
  %402 = icmp eq i64 %index.next1646, %n.vec1633
  br i1 %402, label %middle.block1628, label %vector.body1636

middle.block1628:                                 ; preds = %vector.body1636
  %bin.rdx1649 = fadd reassoc contract <4 x double> %401, %400
  %403 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1649)
  %bin.rdx1647 = fadd reassoc contract <4 x double> %397, %396
  %404 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1647)
  %cmp.n1635 = icmp eq i64 %arraylen533, %n.vec1633
  br i1 %cmp.n1635, label %L687, label %scalar.ph1629

scalar.ph1629:                                    ; preds = %middle.block1628, %L659.lr.ph
  %bc.resume.val1634 = phi i64 [ %n.vec1633, %middle.block1628 ], [ 0, %L659.lr.ph ]
  %bc.merge.rdx1648 = phi double [ %404, %middle.block1628 ], [ 0.000000e+00, %L659.lr.ph ]
  %bc.merge.rdx1650 = phi double [ %403, %middle.block1628 ], [ 0.000000e+00, %L659.lr.ph ]
  br label %L659

L659:                                             ; preds = %L659, %scalar.ph1629
  %value_phi538893 = phi i64 [ %bc.resume.val1634, %scalar.ph1629 ], [ %412, %L659 ]
  %value_phi537892 = phi double [ %bc.merge.rdx1648, %scalar.ph1629 ], [ %409, %L659 ]
  %value_phi536891 = phi double [ %bc.merge.rdx1650, %scalar.ph1629 ], [ %411, %L659 ]
  %405 = add i64 %382, %value_phi538893
  %406 = getelementptr inbounds double, double* %arrayptr543693, i64 %405
  %arrayref544 = load double, double* %406, align 8
  %407 = getelementptr inbounds double, double* %arrayptr546694, i64 %value_phi538893
  %arrayref547 = load double, double* %407, align 8
  %408 = fmul contract double %arrayref544, %arrayref547
  %409 = fadd reassoc contract double %value_phi537892, %408
  %410 = fmul contract double %arrayref547, %arrayref547
  %411 = fadd reassoc contract double %value_phi536891, %410
  %412 = add nuw nsw i64 %value_phi538893, 1
  %exitcond1051.not = icmp eq i64 %412, %arraylen533
  br i1 %exitcond1051.not, label %L687, label %L659

L687:                                             ; preds = %L659, %middle.block1628, %L646, %L617, %middle.block1651, %L603
  %value_phi329 = phi double [ 0.000000e+00, %L603 ], [ 0.000000e+00, %L646 ], [ %403, %middle.block1628 ], [ %367, %middle.block1651 ], [ %411, %L659 ], [ %378, %L617 ]
  %value_phi330 = phi double [ 0.000000e+00, %L603 ], [ 0.000000e+00, %L646 ], [ %404, %middle.block1628 ], [ %368, %middle.block1651 ], [ %409, %L659 ], [ %376, %L617 ]
  %value_phi331 = phi double [ 0.000000e+00, %L603 ], [ %arrayref304, %L646 ], [ %arrayref304, %middle.block1628 ], [ %369, %middle.block1651 ], [ %arrayref304, %L659 ], [ %374, %L617 ]
  %413 = fsub double %value_phi329, %value_phi329
  %414 = fcmp uno double %413, 0.000000e+00
  br i1 %414, label %L692, label %L694

L692:                                             ; preds = %L687
  %415 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %getfield289, {}** %415, align 8
  %416 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 2
  store {}* %getfield293, {}** %416, align 16
  call void @j__check_residual_1241({}* nonnull %getfield293, i64 signext %arrayref287)
  br label %L694

L694:                                             ; preds = %L692, %L687
  %417 = fcmp une double %value_phi331, 0.000000e+00
  br i1 %417, label %L735, label %L696

L696:                                             ; preds = %L694
  %getfield333 = load atomic {}*, {}** %334 unordered, align 8
  %418 = bitcast {}* %getfield333 to {}**
  %arraysize_ptr334 = getelementptr inbounds {}*, {}** %418, i64 3
  %419 = bitcast {}** %arraysize_ptr334 to i64*
  %arraysize335 = load i64, i64* %419, align 8
  %.not657.not = icmp eq i64 %arraysize335, 0
  br i1 %.not657.not, label %L735, label %L709.preheader

L709.preheader:                                   ; preds = %L696
  %arraysize_ptr349 = getelementptr inbounds {}*, {}** %418, i64 4
  %420 = bitcast {}** %arraysize_ptr349 to i64*
  %arraysize350 = load i64, i64* %420, align 8
  %inbounds351 = icmp ult i64 %338, %arraysize350
  %421 = mul i64 %arraysize335, %338
  %422 = bitcast {}* %getfield333 to double**
  %arrayptr356659 = load double*, double** %422, align 8
  %inbounds351.fr = freeze i1 %inbounds351
  br i1 %inbounds351.fr, label %ib347.us, label %oob352

ib347.us:                                         ; preds = %L715.us, %L709.preheader
  %value_phi340.us = phi i64 [ %427, %L715.us ], [ 1, %L709.preheader ]
  %423 = add nsw i64 %value_phi340.us, -1
  %424 = add i64 %421, %423
  %425 = getelementptr inbounds double, double* %arrayptr356659, i64 %424
  %arrayref357.us = load double, double* %425, align 8
  %426 = fcmp une double %arrayref357.us, 0.000000e+00
  br i1 %426, label %L731.split.us, label %L715.us

L715.us:                                          ; preds = %ib347.us
  %427 = add nuw nsw i64 %value_phi340.us, 1
  %428 = icmp ult i64 %value_phi340.us, %arraysize335
  br i1 %428, label %ib347.us, label %L735

L731.split.us:                                    ; preds = %ib347.us
  store {}* inttoptr (i64 135794558905424 to {}*), {}** %6, align 8
  %429 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %429)
  unreachable

L735:                                             ; preds = %L715.us, %L696, %L694
  %430 = fsub double %value_phi331, %value_phi331
  %431 = fcmp uno double %430, 0.000000e+00
  br i1 %431, label %L1048, label %L740

L740:                                             ; preds = %L735
  %getfield365 = load atomic {}*, {}** %321 unordered, align 8
  %432 = bitcast {}* %getfield365 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr367 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %432, i64 0, i32 1
  %arraylen368 = load i64, i64* %arraylen_ptr367, align 8
  %.not661 = icmp ult i64 %338, %arraylen368
  br i1 %.not661, label %L754, label %L751

L751:                                             ; preds = %L740
  store i64 %arrayref287, i64* %322, align 8
  %433 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 2
  store {}* %getfield365, {}** %433, align 16
  call void @j_throw_boundserror_1236({}* nonnull %getfield365, [1 x i64]* nocapture readonly %newstruct366) #3
  unreachable

L754:                                             ; preds = %L740
  %434 = bitcast {}* %getfield365 to i64**
  %arrayptr373662 = load i64*, i64** %434, align 8
  %435 = getelementptr inbounds i64, i64* %arrayptr373662, i64 %338
  %arrayref374 = load i64, i64* %435, align 8
  %.not663 = icmp eq i64 %arrayref374, 0
  br i1 %.not663, label %L764, label %L759

L759:                                             ; preds = %L754
  %436 = bitcast {}* %0 to double***
  %getfield5241863 = load atomic double**, double*** %436 unordered, align 8
  %437 = add i64 %arrayref374, -1
  %arrayptr526690 = load double*, double** %getfield5241863, align 8
  %438 = getelementptr inbounds double, double* %arrayptr526690, i64 %437
  %arrayref527 = load double, double* %438, align 8
  br label %L764

L764:                                             ; preds = %L759, %L754
  %value_phi375 = phi double [ %arrayref527, %L759 ], [ 0.000000e+00, %L754 ]
  br i1 %417, label %L768, label %L766

L766:                                             ; preds = %L764
  %439 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %getfield289, {}** %439, align 8
  %440 = call double @j__coordinate_minimizer_1234({ double }* nocapture nonnull readonly %2, double %value_phi375, i64 signext %arrayref287)
  br label %L966

L768:                                             ; preds = %L764
  %getfield465 = load atomic {}*, {}** %319 unordered, align 8
  %441 = bitcast {}* %getfield465 to i8*
  %getfield_addr466 = getelementptr inbounds i8, i8* %441, i64 24
  %442 = bitcast i8* %getfield_addr466 to {}**
  %getfield467 = load atomic {}*, {}** %442 unordered, align 8
  %443 = bitcast {}* %getfield467 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr468 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %443, i64 0, i32 1
  %arraylen469 = load i64, i64* %arraylen_ptr468, align 8
  %444 = sitofp i64 %arraylen469 to double
  %445 = fmul double %444, 0x350000000000000
  %446 = fcmp ole double %445, %value_phi331
  %447 = fcmp ord double %413, 0.000000e+00
  %448 = fcmp ole double %445, %value_phi329
  %449 = and i1 %447, %448
  %450 = and i1 %446, %449
  br i1 %450, label %L787, label %L963

L787:                                             ; preds = %L768
  %aggregate_load_box470.sroa.0.0.copyload = load double, double* %aggregate_load_box470.sroa.0.0..sroa_idx, align 1
  %451 = fcmp uge double %value_phi331, 0.000000e+00
  br i1 %451, label %L793, label %L791

L791:                                             ; preds = %L787
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %value_phi331) #3
  unreachable

L793:                                             ; preds = %L787
  %452 = call double @llvm.sqrt.f64(double %value_phi331)
  %453 = fcmp ugt double %452, %aggregate_load_box470.sroa.0.0.copyload
  br i1 %453, label %L798, label %L966

L798:                                             ; preds = %L793
  %454 = fdiv double %value_phi330, %value_phi331
  %455 = fadd double %454, %value_phi375
  %456 = fmul double %value_phi330, %454
  %457 = fsub double %value_phi329, %456
  %458 = fmul double %value_phi329, 6.250000e-02
  %459 = fcmp uge double %457, %458
  br i1 %459, label %L853, label %L805

L805:                                             ; preds = %L798
  %.not680 = icmp eq i64 %arraylen469, 0
  br i1 %.not680, label %L842, label %L819.lr.ph

L819.lr.ph:                                       ; preds = %L805
  %460 = bitcast {}* %getfield465 to {}**
  %getfield475 = load atomic {}*, {}** %460 unordered, align 8
  %461 = bitcast {}* %getfield467 to double**
  %arrayptr485682 = load double*, double** %461, align 8
  %462 = bitcast {}* %getfield475 to {}**
  %arraysize_ptr487 = getelementptr inbounds {}*, {}** %462, i64 3
  %463 = bitcast {}** %arraysize_ptr487 to i64*
  %arraysize488 = load i64, i64* %463, align 8
  %464 = mul i64 %arraysize488, %338
  %465 = bitcast {}* %getfield475 to double**
  %arrayptr491683 = load double*, double** %465, align 8
  %min.iters.check1595 = icmp ult i64 %arraylen469, 16
  br i1 %min.iters.check1595, label %scalar.ph1594, label %vector.ph1596

vector.ph1596:                                    ; preds = %L819.lr.ph
  %n.vec1598 = and i64 %arraylen469, 9223372036854775792
  %broadcast.splatinsert1615 = insertelement <4 x double> poison, double %454, i64 0
  %broadcast.splat1616 = shufflevector <4 x double> %broadcast.splatinsert1615, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1601

vector.body1601:                                  ; preds = %vector.body1601, %vector.ph1596
  %index1602 = phi i64 [ 0, %vector.ph1596 ], [ %index.next1623, %vector.body1601 ]
  %vec.phi1603 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1596 ], [ %495, %vector.body1601 ]
  %vec.phi1604 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1596 ], [ %496, %vector.body1601 ]
  %vec.phi1605 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1596 ], [ %497, %vector.body1601 ]
  %vec.phi1606 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1596 ], [ %498, %vector.body1601 ]
  %466 = getelementptr inbounds double, double* %arrayptr485682, i64 %index1602
  %467 = bitcast double* %466 to <4 x double>*
  %wide.load1607 = load <4 x double>, <4 x double>* %467, align 8
  %468 = getelementptr inbounds double, double* %466, i64 4
  %469 = bitcast double* %468 to <4 x double>*
  %wide.load1608 = load <4 x double>, <4 x double>* %469, align 8
  %470 = getelementptr inbounds double, double* %466, i64 8
  %471 = bitcast double* %470 to <4 x double>*
  %wide.load1609 = load <4 x double>, <4 x double>* %471, align 8
  %472 = getelementptr inbounds double, double* %466, i64 12
  %473 = bitcast double* %472 to <4 x double>*
  %wide.load1610 = load <4 x double>, <4 x double>* %473, align 8
  %474 = add i64 %464, %index1602
  %475 = getelementptr inbounds double, double* %arrayptr491683, i64 %474
  %476 = bitcast double* %475 to <4 x double>*
  %wide.load1611 = load <4 x double>, <4 x double>* %476, align 8
  %477 = getelementptr inbounds double, double* %475, i64 4
  %478 = bitcast double* %477 to <4 x double>*
  %wide.load1612 = load <4 x double>, <4 x double>* %478, align 8
  %479 = getelementptr inbounds double, double* %475, i64 8
  %480 = bitcast double* %479 to <4 x double>*
  %wide.load1613 = load <4 x double>, <4 x double>* %480, align 8
  %481 = getelementptr inbounds double, double* %475, i64 12
  %482 = bitcast double* %481 to <4 x double>*
  %wide.load1614 = load <4 x double>, <4 x double>* %482, align 8
  %483 = fmul <4 x double> %broadcast.splat1616, %wide.load1611
  %484 = fmul <4 x double> %broadcast.splat1616, %wide.load1612
  %485 = fmul <4 x double> %broadcast.splat1616, %wide.load1613
  %486 = fmul <4 x double> %broadcast.splat1616, %wide.load1614
  %487 = fsub <4 x double> %wide.load1607, %483
  %488 = fsub <4 x double> %wide.load1608, %484
  %489 = fsub <4 x double> %wide.load1609, %485
  %490 = fsub <4 x double> %wide.load1610, %486
  %491 = fmul contract <4 x double> %487, %487
  %492 = fmul contract <4 x double> %488, %488
  %493 = fmul contract <4 x double> %489, %489
  %494 = fmul contract <4 x double> %490, %490
  %495 = fadd reassoc contract <4 x double> %vec.phi1603, %491
  %496 = fadd reassoc contract <4 x double> %vec.phi1604, %492
  %497 = fadd reassoc contract <4 x double> %vec.phi1605, %493
  %498 = fadd reassoc contract <4 x double> %vec.phi1606, %494
  %index.next1623 = add nuw i64 %index1602, 16
  %499 = icmp eq i64 %index.next1623, %n.vec1598
  br i1 %499, label %middle.block1593, label %vector.body1601

middle.block1593:                                 ; preds = %vector.body1601
  %bin.rdx1624 = fadd reassoc contract <4 x double> %496, %495
  %bin.rdx1625 = fadd reassoc contract <4 x double> %497, %bin.rdx1624
  %bin.rdx1626 = fadd reassoc contract <4 x double> %498, %bin.rdx1625
  %500 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1626)
  %cmp.n1600 = icmp eq i64 %arraylen469, %n.vec1598
  br i1 %cmp.n1600, label %L842, label %scalar.ph1594

scalar.ph1594:                                    ; preds = %middle.block1593, %L819.lr.ph
  %bc.resume.val1599 = phi i64 [ %n.vec1598, %middle.block1593 ], [ 0, %L819.lr.ph ]
  %bc.merge.rdx1627 = phi double [ %500, %middle.block1593 ], [ 0.000000e+00, %L819.lr.ph ]
  br label %L819

L819:                                             ; preds = %L819, %scalar.ph1594
  %value_phi483898 = phi i64 [ %bc.resume.val1599, %scalar.ph1594 ], [ %508, %L819 ]
  %value_phi482897 = phi double [ %bc.merge.rdx1627, %scalar.ph1594 ], [ %507, %L819 ]
  %501 = getelementptr inbounds double, double* %arrayptr485682, i64 %value_phi483898
  %arrayref486 = load double, double* %501, align 8
  %502 = add i64 %464, %value_phi483898
  %503 = getelementptr inbounds double, double* %arrayptr491683, i64 %502
  %arrayref492 = load double, double* %503, align 8
  %504 = fmul double %454, %arrayref492
  %505 = fsub double %arrayref486, %504
  %506 = fmul contract double %505, %505
  %507 = fadd reassoc contract double %value_phi482897, %506
  %508 = add nuw nsw i64 %value_phi483898, 1
  %exitcond1052.not = icmp eq i64 %508, %arraylen469
  br i1 %exitcond1052.not, label %L842, label %L819

L842:                                             ; preds = %L819, %middle.block1593, %L805
  %value_phi494 = phi double [ 0.000000e+00, %L805 ], [ %500, %middle.block1593 ], [ %507, %L819 ]
  %509 = fsub double %value_phi494, %value_phi494
  %510 = fcmp uno double %509, 0.000000e+00
  %511 = fcmp ugt double %445, %value_phi494
  %512 = or i1 %511, %510
  br i1 %512, label %L851, label %L853

L851:                                             ; preds = %L842
  %513 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %getfield289, {}** %513, align 8
  %514 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi375, i64 signext %arrayref287)
  br label %L966

L853:                                             ; preds = %L842, %L798
  %value_phi496 = phi double [ %457, %L798 ], [ %value_phi494, %L842 ]
  %515 = fcmp uge double %value_phi496, 0.000000e+00
  br i1 %515, label %L858, label %L856

L856:                                             ; preds = %L853
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %value_phi496) #3
  unreachable

L858:                                             ; preds = %L853
  %516 = call double @llvm.sqrt.f64(double %value_phi496)
  %517 = fsub double %452, %aggregate_load_box470.sroa.0.0.copyload
  %518 = fcmp uge double %517, 0.000000e+00
  br i1 %518, label %L865, label %L863

L863:                                             ; preds = %L858
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %517) #3
  unreachable

L865:                                             ; preds = %L858
  %519 = fadd double %452, %aggregate_load_box470.sroa.0.0.copyload
  %520 = fcmp uge double %519, 0.000000e+00
  br i1 %520, label %L872, label %L870

L870:                                             ; preds = %L865
  call void @j_throw_complex_domainerror_1237({}* inttoptr (i64 135794596555280 to {}*), double %519) #3
  unreachable

L872:                                             ; preds = %L865
  %521 = call double @llvm.sqrt.f64(double %517)
  %522 = call double @llvm.sqrt.f64(double %519)
  %523 = fmul double %521, %522
  %524 = fmul double %452, %523
  %525 = fdiv double %516, %524
  %526 = fmul double %aggregate_load_box470.sroa.0.0.copyload, %525
  %527 = fcmp oge double %524, 0x10000000000000
  %528 = fcmp oge double %525, 0x10000000000000
  %529 = fcmp ole double %525, 0x7FEFFFFFFFFFFFFF
  %narrow684 = and i1 %528, %529
  %530 = and i1 %527, %narrow684
  %531 = fcmp oge double %526, 0x10000000000000
  %532 = fcmp ole double %526, 0x7FEFFFFFFFFFFFFF
  %narrow685 = and i1 %531, %532
  %533 = and i1 %530, %narrow685
  br i1 %533, label %L906, label %L961

L906:                                             ; preds = %L872
  %534 = fneg double %526
  %.inv687 = fcmp ogt double %455, %534
  %535 = select i1 %.inv687, double %455, double %534
  %.inv688 = fcmp olt double %535, %526
  %536 = select i1 %.inv688, double %535, double %526
  %537 = fsub double %455, %536
  %538 = fadd double %537, 0.000000e+00
  br label %L966

L961:                                             ; preds = %L872
  %539 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %getfield289, {}** %539, align 8
  %540 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi375, i64 signext %arrayref287)
  br label %L966

L963:                                             ; preds = %L768
  %541 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 3
  store {}* %getfield289, {}** %541, align 8
  %542 = call double @j__sqrt_offrange_step_1239({}* nonnull %1, double %value_phi375, i64 signext %arrayref287)
  br label %L966

L966:                                             ; preds = %L963, %L961, %L906, %L851, %L793, %L766
  %value_phi376 = phi double [ %440, %L766 ], [ %514, %L851 ], [ %540, %L961 ], [ %542, %L963 ], [ 0.000000e+00, %L793 ], [ %538, %L906 ]
  %getfield378 = load atomic {}*, {}** %337 unordered, align 8
  %543 = bitcast {}* %getfield378 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr379 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %543, i64 0, i32 1
  %arraylen380 = load i64, i64* %arraylen_ptr379, align 8
  %inbounds381 = icmp ult i64 %338, %arraylen380
  br i1 %inbounds381, label %idxend384, label %oob382

L974:                                             ; preds = %idxend384
  %getfield398 = load atomic {}*, {}** %321 unordered, align 8
  %544 = bitcast {}* %getfield398 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr400 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %544, i64 0, i32 1
  %arraylen401 = load i64, i64* %arraylen_ptr400, align 8
  %.not668 = icmp ult i64 %338, %arraylen401
  br i1 %.not668, label %L988, label %L985

L985:                                             ; preds = %L974
  store i64 %arrayref287, i64* %326, align 8
  %545 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 2
  store {}* %getfield398, {}** %545, align 16
  call void @j_throw_boundserror_1236({}* nonnull %getfield398, [1 x i64]* nocapture readonly %newstruct399) #3
  unreachable

L988:                                             ; preds = %L974
  %546 = bitcast {}* %getfield398 to i64**
  %arrayptr406669 = load i64*, i64** %546, align 8
  %547 = getelementptr inbounds i64, i64* %arrayptr406669, i64 %338
  %arrayref407 = load i64, i64* %547, align 8
  %.not670 = icmp eq i64 %arrayref407, 0
  br i1 %.not670, label %L996, label %L993

L993:                                             ; preds = %L988
  %548 = bitcast {}* %0 to double***
  %getfield4091864 = load atomic double**, double*** %548 unordered, align 8
  %549 = add i64 %arrayref407, -1
  %arrayptr411671 = load double*, double** %getfield4091864, align 8
  %550 = getelementptr inbounds double, double* %arrayptr411671, i64 %549
  store double %value_phi376, double* %550, align 8
  br label %L1013

L996:                                             ; preds = %L988
  %551 = fcmp oeq double %value_phi376, 0.000000e+00
  br i1 %551, label %L1013, label %L999

L999:                                             ; preds = %L996
  %552 = load i64, i64* %328, align 8
  %553 = add i64 %552, 1
  store i64 %553, i64* %328, align 8
  %getfield434 = load atomic {}*, {}** %323 unordered, align 8
  %554 = bitcast {}* %getfield434 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr435 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %554, i64 0, i32 1
  %arraylen436 = load i64, i64* %arraylen_ptr435, align 8
  %inbounds437 = icmp ult i64 %552, %arraylen436
  br i1 %inbounds437, label %idxend440, label %oob438

L1013:                                            ; preds = %idxend460, %L996, %L993
  %getfield413 = load atomic {}*, {}** %336 unordered, align 8
  %555 = bitcast {}* %getfield413 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr416 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %555, i64 0, i32 1
  %arraylen417 = load i64, i64* %arraylen_ptr416, align 8
  %.not672 = icmp eq i64 %arraylen417, 0
  br i1 %.not672, label %L1050, label %L1026.lr.ph

L1026.lr.ph:                                      ; preds = %L1013
  %getfield415 = load atomic {}*, {}** %334 unordered, align 8
  %556 = bitcast {}* %getfield413 to double**
  %arrayptr422674 = load double*, double** %556, align 8
  %557 = bitcast {}* %getfield415 to {}**
  %arraysize_ptr424 = getelementptr inbounds {}*, {}** %557, i64 3
  %558 = bitcast {}** %arraysize_ptr424 to i64*
  %arraysize425 = load i64, i64* %558, align 8
  %559 = mul i64 %arraysize425, %338
  %560 = bitcast {}* %getfield415 to double**
  %arrayptr428675 = load double*, double** %560, align 8
  %min.iters.check1568 = icmp ult i64 %arraylen417, 16
  br i1 %min.iters.check1568, label %scalar.ph1567, label %vector.memcheck1555

vector.memcheck1555:                              ; preds = %L1026.lr.ph
  %scevgep1557 = getelementptr double, double* %arrayptr422674, i64 %arraylen417
  %scevgep1559 = getelementptr double, double* %arrayptr428675, i64 %559
  %561 = add i64 %arraylen417, %559
  %scevgep1561 = getelementptr double, double* %arrayptr428675, i64 %561
  %bound01563 = icmp ult double* %arrayptr422674, %scevgep1561
  %bound11564 = icmp ult double* %scevgep1559, %scevgep1557
  %found.conflict1565 = and i1 %bound01563, %bound11564
  br i1 %found.conflict1565, label %scalar.ph1567, label %vector.ph1569

vector.ph1569:                                    ; preds = %vector.memcheck1555
  %n.vec1571 = and i64 %arraylen417, 9223372036854775792
  %broadcast.splatinsert1584 = insertelement <4 x double> poison, double %627, i64 0
  %broadcast.splat1585 = shufflevector <4 x double> %broadcast.splatinsert1584, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1574

vector.body1574:                                  ; preds = %vector.body1574, %vector.ph1569
  %index1575 = phi i64 [ 0, %vector.ph1569 ], [ %index.next1592, %vector.body1574 ]
  %562 = getelementptr inbounds double, double* %arrayptr422674, i64 %index1575
  %563 = bitcast double* %562 to <4 x double>*
  %wide.load1576 = load <4 x double>, <4 x double>* %563, align 8
  %564 = getelementptr inbounds double, double* %562, i64 4
  %565 = bitcast double* %564 to <4 x double>*
  %wide.load1577 = load <4 x double>, <4 x double>* %565, align 8
  %566 = getelementptr inbounds double, double* %562, i64 8
  %567 = bitcast double* %566 to <4 x double>*
  %wide.load1578 = load <4 x double>, <4 x double>* %567, align 8
  %568 = getelementptr inbounds double, double* %562, i64 12
  %569 = bitcast double* %568 to <4 x double>*
  %wide.load1579 = load <4 x double>, <4 x double>* %569, align 8
  %570 = add i64 %559, %index1575
  %571 = getelementptr inbounds double, double* %arrayptr428675, i64 %570
  %572 = bitcast double* %571 to <4 x double>*
  %wide.load1580 = load <4 x double>, <4 x double>* %572, align 8
  %573 = getelementptr inbounds double, double* %571, i64 4
  %574 = bitcast double* %573 to <4 x double>*
  %wide.load1581 = load <4 x double>, <4 x double>* %574, align 8
  %575 = getelementptr inbounds double, double* %571, i64 8
  %576 = bitcast double* %575 to <4 x double>*
  %wide.load1582 = load <4 x double>, <4 x double>* %576, align 8
  %577 = getelementptr inbounds double, double* %571, i64 12
  %578 = bitcast double* %577 to <4 x double>*
  %wide.load1583 = load <4 x double>, <4 x double>* %578, align 8
  %579 = fmul <4 x double> %broadcast.splat1585, %wide.load1580
  %580 = fmul <4 x double> %broadcast.splat1585, %wide.load1581
  %581 = fmul <4 x double> %broadcast.splat1585, %wide.load1582
  %582 = fmul <4 x double> %broadcast.splat1585, %wide.load1583
  %583 = fsub <4 x double> %wide.load1576, %579
  %584 = fsub <4 x double> %wide.load1577, %580
  %585 = fsub <4 x double> %wide.load1578, %581
  %586 = fsub <4 x double> %wide.load1579, %582
  store <4 x double> %583, <4 x double>* %563, align 8
  store <4 x double> %584, <4 x double>* %565, align 8
  store <4 x double> %585, <4 x double>* %567, align 8
  store <4 x double> %586, <4 x double>* %569, align 8
  %index.next1592 = add nuw i64 %index1575, 16
  %587 = icmp eq i64 %index.next1592, %n.vec1571
  br i1 %587, label %middle.block1566, label %vector.body1574

middle.block1566:                                 ; preds = %vector.body1574
  %cmp.n1573 = icmp eq i64 %arraylen417, %n.vec1571
  br i1 %cmp.n1573, label %L1050, label %scalar.ph1567

scalar.ph1567:                                    ; preds = %middle.block1566, %vector.memcheck1555, %L1026.lr.ph
  %bc.resume.val1572 = phi i64 [ %n.vec1571, %middle.block1566 ], [ 0, %L1026.lr.ph ], [ 0, %vector.memcheck1555 ]
  br label %L1026

L1026:                                            ; preds = %L1026, %scalar.ph1567
  %value_phi420901 = phi i64 [ %bc.resume.val1572, %scalar.ph1567 ], [ %593, %L1026 ]
  %588 = getelementptr inbounds double, double* %arrayptr422674, i64 %value_phi420901
  %arrayref423 = load double, double* %588, align 8
  %589 = add i64 %559, %value_phi420901
  %590 = getelementptr inbounds double, double* %arrayptr428675, i64 %589
  %arrayref429 = load double, double* %590, align 8
  %591 = fmul double %627, %arrayref429
  %592 = fsub double %arrayref423, %591
  store double %592, double* %588, align 8
  %593 = add nuw nsw i64 %value_phi420901, 1
  %exitcond1053.not = icmp eq i64 %593, %arraylen417
  br i1 %exitcond1053.not, label %L1050, label %L1026

L1048:                                            ; preds = %L735
  call void @j__refuse_curvature_1240(i64 signext %arrayref287) #3
  unreachable

L1050:                                            ; preds = %idxend384, %L1026, %middle.block1566, %L1013
  %arrayref2871005 = phi i64 [ %arrayref287, %L1013 ], [ %arrayref2871006, %idxend384 ], [ %arrayref287, %middle.block1566 ], [ %arrayref287, %L1026 ]
  %594 = call double @llvm.fabs.f64(double %627)
  %595 = fcmp oeq double %627, 0.000000e+00
  %or.cond1302 = select i1 %.not665, i1 true, i1 %595
  br i1 %or.cond1302, label %L1061, label %L1056

L1056:                                            ; preds = %L1050
  %getfield389 = load atomic {}*, {}** %319 unordered, align 8
  %596 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1858, i64 0, i64 2
  store {}* %getfield389, {}** %596, align 16
  %597 = call double @j_coordinate_scale_1235({}* nonnull %getfield389, {}* nonnull %0, i64 signext %arrayref287)
  %598 = fmul double %594, %597
  br label %L1061

L1061:                                            ; preds = %L1056, %L1050
  %value_phi390 = phi double [ %598, %L1056 ], [ %594, %L1050 ]
  %599 = fsub double %value_phi390, %value_phi390
  %600 = fcmp uno double %599, 0.000000e+00
  br i1 %600, label %L1067, label %L1070

L1067:                                            ; preds = %L1061
  store {}* inttoptr (i64 135794567639056 to {}*), {}** %6, align 8
  %601 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %601)
  unreachable

L1070:                                            ; preds = %L1061
  %.inv666 = fcmp olt double %value_phi277, %value_phi390
  %602 = select i1 %.inv666, double %value_phi390, double %value_phi277
  %.not667.not = icmp eq i64 %value_phi275, %18
  %603 = add nuw i64 %value_phi275, 1
  br i1 %.not667.not, label %L1085.loopexit, label %L567

L1085.loopexit:                                   ; preds = %L1070
  store i64 %arrayref287, i64* %322, align 8
  store i64 %arrayref2871005, i64* %326, align 8
  br label %L1085

L1085.loopexit699:                                ; preds = %L534
  store i64 %arrayref16, i64* %31, align 8
  store i64 %arrayref16944, i64* %35, align 8
  br label %L1085

L1085:                                            ; preds = %L1085.loopexit699, %L1085.loopexit, %L551, %L12
  %value_phi113 = phi double [ 0.000000e+00, %L12 ], [ 0.000000e+00, %L551 ], [ %602, %L1085.loopexit ], [ %315, %L1085.loopexit699 ]
  %604 = load {}*, {}** %10, align 8
  %605 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %604, {}** %605, align 8
  ret double %value_phi113

oob:                                              ; preds = %L30
  %errorbox = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield24, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L30
  %606 = bitcast {}* %getfield24 to double**
  %arrayptr26608 = load double*, double** %606, align 8
  %607 = getelementptr inbounds double, double* %arrayptr26608, i64 %49
  %arrayref27 = load double, double* %607, align 8
  %608 = fcmp ord double %arrayref27, 0.000000e+00
  %609 = bitcast {}* %getfield22 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr249 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %609, i64 0, i32 1
  %arraylen250 = load i64, i64* %arraylen_ptr249, align 8
  %.not645 = icmp eq i64 %arraylen250, 0
  br i1 %608, label %L110, label %L67

oob70:                                            ; preds = %L173.preheader
  %errorbox71614 = alloca [2 x i64], align 8
  %errorbox71614.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 0
  store i64 1, i64* %errorbox71614.sub, align 8
  %610 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox71614, i64 0, i64 1
  store i64 %arrayref16, i64* %610, align 8
  call void @ijl_bounds_error_ints({}* %getfield52, i64* nonnull %errorbox71614.sub, i64 2)
  unreachable

oob99:                                            ; preds = %L430
  %errorbox100 = alloca i64, align 8
  store i64 %arrayref16, i64* %errorbox100, align 8
  call void @ijl_bounds_error_ints({}* %getfield95, i64* nonnull %errorbox100, i64 1)
  unreachable

idxend101:                                        ; preds = %L430
  %611 = bitcast {}* %getfield95 to double**
  %arrayptr103620 = load double*, double** %611, align 8
  %612 = getelementptr inbounds double, double* %arrayptr103620, i64 %49
  store double %value_phi50, double* %612, align 8
  %613 = fsub double %value_phi93, %value_phi92
  %614 = fcmp une double %613, 0.000000e+00
  br i1 %614, label %L438, label %L514

oob157:                                           ; preds = %L463
  %errorbox158 = alloca i64, align 8
  store i64 %266, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend159:                                        ; preds = %L463
  %615 = bitcast {}* %getfield153 to double**
  %arrayptr161632 = load double*, double** %615, align 8
  %616 = getelementptr inbounds double, double* %arrayptr161632, i64 %265
  store double %value_phi93, double* %616, align 8
  %getfield163 = load atomic {}*, {}** %38 unordered, align 8
  %617 = bitcast {}* %getfield163 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr164 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %617, i64 0, i32 1
  %arraylen165 = load i64, i64* %arraylen_ptr164, align 8
  %inbounds166 = icmp ult i64 %265, %arraylen165
  br i1 %inbounds166, label %idxend179, label %oob167

oob167:                                           ; preds = %idxend159
  %errorbox168 = alloca i64, align 8
  store i64 %266, i64* %errorbox168, align 8
  call void @ijl_bounds_error_ints({}* %getfield163, i64* nonnull %errorbox168, i64 1)
  unreachable

idxend179:                                        ; preds = %idxend159
  %618 = bitcast {}* %getfield163 to i64**
  %arrayptr171633 = load i64*, i64** %618, align 8
  %619 = getelementptr inbounds i64, i64* %arrayptr171633, i64 %265
  store i64 %arrayref16, i64* %619, align 8
  store i64 %266, i64* %260, align 8
  br label %L477

oob299:                                           ; preds = %L567
  %errorbox300 = alloca i64, align 8
  store i64 %arrayref287, i64* %errorbox300, align 8
  call void @ijl_bounds_error_ints({}* %getfield295, i64* nonnull %errorbox300, i64 1)
  unreachable

idxend301:                                        ; preds = %L567
  %620 = bitcast {}* %getfield295 to double**
  %arrayptr303652 = load double*, double** %620, align 8
  %621 = getelementptr inbounds double, double* %arrayptr303652, i64 %338
  %arrayref304 = load double, double* %621, align 8
  %622 = fcmp ord double %arrayref304, 0.000000e+00
  %623 = bitcast {}* %getfield293 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr532 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %623, i64 0, i32 1
  %arraylen533 = load i64, i64* %arraylen_ptr532, align 8
  %.not691 = icmp eq i64 %arraylen533, 0
  br i1 %622, label %L646, label %L603

oob352:                                           ; preds = %L709.preheader
  %errorbox353658 = alloca [2 x i64], align 8
  %errorbox353658.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox353658, i64 0, i64 0
  store i64 1, i64* %errorbox353658.sub, align 8
  %624 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox353658, i64 0, i64 1
  store i64 %arrayref287, i64* %624, align 8
  call void @ijl_bounds_error_ints({}* %getfield333, i64* nonnull %errorbox353658.sub, i64 2)
  unreachable

oob382:                                           ; preds = %L966
  %errorbox383 = alloca i64, align 8
  store i64 %arrayref287, i64* %errorbox383, align 8
  call void @ijl_bounds_error_ints({}* %getfield378, i64* nonnull %errorbox383, i64 1)
  unreachable

idxend384:                                        ; preds = %L966
  %625 = bitcast {}* %getfield378 to double**
  %arrayptr386664 = load double*, double** %625, align 8
  %626 = getelementptr inbounds double, double* %arrayptr386664, i64 %338
  store double %value_phi331, double* %626, align 8
  %627 = fsub double %value_phi376, %value_phi375
  %628 = fcmp une double %627, 0.000000e+00
  br i1 %628, label %L974, label %L1050

oob438:                                           ; preds = %L999
  %errorbox439 = alloca i64, align 8
  store i64 %553, i64* %errorbox439, align 8
  call void @ijl_bounds_error_ints({}* %getfield434, i64* nonnull %errorbox439, i64 1)
  unreachable

idxend440:                                        ; preds = %L999
  %629 = bitcast {}* %getfield434 to double**
  %arrayptr442677 = load double*, double** %629, align 8
  %630 = getelementptr inbounds double, double* %arrayptr442677, i64 %552
  store double %value_phi376, double* %630, align 8
  %getfield444 = load atomic {}*, {}** %329 unordered, align 8
  %631 = bitcast {}* %getfield444 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr445 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %631, i64 0, i32 1
  %arraylen446 = load i64, i64* %arraylen_ptr445, align 8
  %inbounds447 = icmp ult i64 %552, %arraylen446
  br i1 %inbounds447, label %idxend460, label %oob448

oob448:                                           ; preds = %idxend440
  %errorbox449 = alloca i64, align 8
  store i64 %553, i64* %errorbox449, align 8
  call void @ijl_bounds_error_ints({}* %getfield444, i64* nonnull %errorbox449, i64 1)
  unreachable

idxend460:                                        ; preds = %idxend440
  %632 = bitcast {}* %getfield444 to i64**
  %arrayptr452678 = load i64*, i64** %632, align 8
  %633 = getelementptr inbounds i64, i64* %arrayptr452678, i64 %552
  store i64 %arrayref287, i64* %633, align 8
  store i64 %553, i64* %547, align 8
  br label %L1013
}
