define double @"julia__sweep!_743"({}* noundef nonnull align 8 dereferenceable(32) %0, {}* noundef nonnull align 8 dereferenceable(80) %1, { double }* nocapture noundef nonnull readonly align 8 dereferenceable(8) %2, {}* noundef nonnull align 8 dereferenceable(56) %3, i8 zeroext %4, [1 x i64]* nocapture noundef nonnull readonly align 8 dereferenceable(8) %5) #0 {
top:
  %6 = alloca {}*, align 8
  %gcframe1848 = alloca [5 x {}*], align 16
  %gcframe1848.sub = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 0
  %7 = bitcast [5 x {}*]* %gcframe1848 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %7, i8 0, i64 40, i1 true)
  %newstruct73 = alloca [1 x i64], align 8
  %newstruct108 = alloca [1 x i64], align 8
  %newstruct349 = alloca [1 x i64], align 8
  %newstruct382 = alloca [1 x i64], align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #14
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [5 x {}*]* %gcframe1848 to i64*
  store i64 12, i64* %9, align 16
  %10 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe1848.sub, {}*** %13, align 8
  %14 = getelementptr inbounds [1 x i64], [1 x i64]* %5, i64 0, i64 0
  %15 = bitcast {}* %3 to i8*
  %16 = load i8, i8* %15, align 8
  %17 = and i8 %16, 1
  %.not = icmp eq i8 %17, 0
  br i1 %.not, label %L527, label %L4

L4:                                               ; preds = %top
  %getfield_addr = getelementptr inbounds i8, i8* %15, i64 8
  %18 = bitcast i8* %getfield_addr to {}**
  %getfield = load atomic {}*, {}** %18 unordered, align 8
  %unbox = load i64, i64* %14, align 8
  %19 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 2
  store {}* %getfield, {}** %19, align 16
  %20 = call nonnull {}* @"j__shuffle!_745"({}* nonnull %getfield, i64 signext %unbox)
  %unbox540 = load i64, i64* %14, align 8
  %.inv = icmp sgt i64 %unbox, 0
  %value_phi = select i1 %.inv, i64 %unbox540, i64 0
  %21 = icmp slt i64 %value_phi, 1
  br i1 %21, label %L1045, label %L22.preheader

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
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %29 to double*
  %30 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct108, i64 0, i64 0
  %31 = getelementptr inbounds i8, i8* %24, i64 24
  %32 = bitcast i8* %31 to i64*
  %getfield_addr152 = getelementptr inbounds i8, i8* %24, i64 8
  %33 = bitcast i8* %getfield_addr152 to {}**
  %34 = and i8 %4, 1
  %.not614 = icmp eq i8 %34, 0
  br label %L22

L22:                                              ; preds = %L510, %L22.preheader
  %arrayref937 = phi i64 [ %arrayref936, %L510 ], [ undef, %L22.preheader ]
  %value_phi5 = phi i64 [ %308, %L510 ], [ 1, %L22.preheader ]
  %value_phi7 = phi double [ %307, %L510 ], [ 0.000000e+00, %L22.preheader ]
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
  %46 = bitcast {}* %getfield12 to double**
  %arrayptr27604 = load double*, double** %46, align 8
  %47 = bitcast {}* %getfield14 to double**
  %arrayptr30605 = load double*, double** %47, align 8
  %min.iters.check1520 = icmp ult i64 %arraylen241, 8
  br i1 %min.iters.check1520, label %scalar.ph1519, label %vector.ph1521

vector.ph1521:                                    ; preds = %L57.lr.ph
  %n.vec1523 = and i64 %arraylen241, 9223372036854775800
  br label %vector.body1526

vector.body1526:                                  ; preds = %vector.body1526, %vector.ph1521
  %index1527 = phi i64 [ 0, %vector.ph1521 ], [ %index.next1538, %vector.body1526 ]
  %vec.phi1528 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %59, %vector.body1526 ]
  %vec.phi1529 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %60, %vector.body1526 ]
  %vec.phi1530 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %63, %vector.body1526 ]
  %vec.phi1531 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %64, %vector.body1526 ]
  %vec.phi1532 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %67, %vector.body1526 ]
  %vec.phi1533 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1521 ], [ %68, %vector.body1526 ]
  %48 = add i64 %45, %index1527
  %49 = getelementptr inbounds double, double* %arrayptr27604, i64 %48
  %50 = bitcast double* %49 to <4 x double>*
  %wide.load1534 = load <4 x double>, <4 x double>* %50, align 8
  %51 = getelementptr inbounds double, double* %49, i64 4
  %52 = bitcast double* %51 to <4 x double>*
  %wide.load1535 = load <4 x double>, <4 x double>* %52, align 8
  %53 = getelementptr inbounds double, double* %arrayptr30605, i64 %index1527
  %54 = bitcast double* %53 to <4 x double>*
  %wide.load1536 = load <4 x double>, <4 x double>* %54, align 8
  %55 = getelementptr inbounds double, double* %53, i64 4
  %56 = bitcast double* %55 to <4 x double>*
  %wide.load1537 = load <4 x double>, <4 x double>* %56, align 8
  %57 = fmul contract <4 x double> %wide.load1534, %wide.load1534
  %58 = fmul contract <4 x double> %wide.load1535, %wide.load1535
  %59 = fadd reassoc contract <4 x double> %vec.phi1528, %57
  %60 = fadd reassoc contract <4 x double> %vec.phi1529, %58
  %61 = fmul contract <4 x double> %wide.load1534, %wide.load1536
  %62 = fmul contract <4 x double> %wide.load1535, %wide.load1537
  %63 = fadd reassoc contract <4 x double> %vec.phi1530, %61
  %64 = fadd reassoc contract <4 x double> %vec.phi1531, %62
  %65 = fmul contract <4 x double> %wide.load1536, %wide.load1536
  %66 = fmul contract <4 x double> %wide.load1537, %wide.load1537
  %67 = fadd reassoc contract <4 x double> %vec.phi1532, %65
  %68 = fadd reassoc contract <4 x double> %vec.phi1533, %66
  %index.next1538 = add nuw i64 %index1527, 8
  %69 = icmp eq i64 %index.next1538, %n.vec1523
  br i1 %69, label %middle.block1518, label %vector.body1526

middle.block1518:                                 ; preds = %vector.body1526
  %bin.rdx1543 = fadd reassoc contract <4 x double> %68, %67
  %70 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1543)
  %bin.rdx1541 = fadd reassoc contract <4 x double> %64, %63
  %71 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1541)
  %bin.rdx1539 = fadd reassoc contract <4 x double> %60, %59
  %72 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1539)
  %cmp.n1525 = icmp eq i64 %arraylen241, %n.vec1523
  br i1 %cmp.n1525, label %L127, label %scalar.ph1519

scalar.ph1519:                                    ; preds = %middle.block1518, %L57.lr.ph
  %bc.resume.val1524 = phi i64 [ %n.vec1523, %middle.block1518 ], [ 0, %L57.lr.ph ]
  %bc.merge.rdx1540 = phi double [ %72, %middle.block1518 ], [ 0.000000e+00, %L57.lr.ph ]
  %bc.merge.rdx1542 = phi double [ %71, %middle.block1518 ], [ 0.000000e+00, %L57.lr.ph ]
  %bc.merge.rdx1544 = phi double [ %70, %middle.block1518 ], [ 0.000000e+00, %L57.lr.ph ]
  br label %L57

L57:                                              ; preds = %L57, %scalar.ph1519
  %value_phi25859 = phi double [ %bc.merge.rdx1540, %scalar.ph1519 ], [ %77, %L57 ]
  %value_phi24858 = phi i64 [ %bc.resume.val1524, %scalar.ph1519 ], [ %82, %L57 ]
  %value_phi23857 = phi double [ %bc.merge.rdx1542, %scalar.ph1519 ], [ %79, %L57 ]
  %value_phi22856 = phi double [ %bc.merge.rdx1544, %scalar.ph1519 ], [ %81, %L57 ]
  %73 = add i64 %45, %value_phi24858
  %74 = getelementptr inbounds double, double* %arrayptr27604, i64 %73
  %arrayref28 = load double, double* %74, align 8
  %75 = getelementptr inbounds double, double* %arrayptr30605, i64 %value_phi24858
  %arrayref31 = load double, double* %75, align 8
  %76 = fmul contract double %arrayref28, %arrayref28
  %77 = fadd reassoc contract double %value_phi25859, %76
  %78 = fmul contract double %arrayref28, %arrayref31
  %79 = fadd reassoc contract double %value_phi23857, %78
  %80 = fmul contract double %arrayref31, %arrayref31
  %81 = fadd reassoc contract double %value_phi22856, %80
  %82 = add nuw nsw i64 %value_phi24858, 1
  %exitcond.not = icmp eq i64 %82, %arraylen241
  br i1 %exitcond.not, label %L127, label %L57

L86:                                              ; preds = %idxend
  br i1 %.not639, label %L127, label %L99.lr.ph

L99.lr.ph:                                        ; preds = %L86
  %83 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr247 = getelementptr inbounds {}*, {}** %83, i64 3
  %84 = bitcast {}** %arraysize_ptr247 to i64*
  %arraysize248 = load i64, i64* %84, align 8
  %85 = mul i64 %arraysize248, %41
  %86 = bitcast {}* %getfield12 to double**
  %arrayptr251641 = load double*, double** %86, align 8
  %87 = bitcast {}* %getfield14 to double**
  %arrayptr254642 = load double*, double** %87, align 8
  %min.iters.check1497 = icmp ult i64 %arraylen241, 8
  br i1 %min.iters.check1497, label %scalar.ph1496, label %vector.ph1498

vector.ph1498:                                    ; preds = %L99.lr.ph
  %n.vec1500 = and i64 %arraylen241, 9223372036854775800
  br label %vector.body1503

vector.body1503:                                  ; preds = %vector.body1503, %vector.ph1498
  %index1504 = phi i64 [ 0, %vector.ph1498 ], [ %index.next1513, %vector.body1503 ]
  %vec.phi1505 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1498 ], [ %99, %vector.body1503 ]
  %vec.phi1506 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1498 ], [ %100, %vector.body1503 ]
  %vec.phi1507 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1498 ], [ %103, %vector.body1503 ]
  %vec.phi1508 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1498 ], [ %104, %vector.body1503 ]
  %88 = add i64 %85, %index1504
  %89 = getelementptr inbounds double, double* %arrayptr251641, i64 %88
  %90 = bitcast double* %89 to <4 x double>*
  %wide.load1509 = load <4 x double>, <4 x double>* %90, align 8
  %91 = getelementptr inbounds double, double* %89, i64 4
  %92 = bitcast double* %91 to <4 x double>*
  %wide.load1510 = load <4 x double>, <4 x double>* %92, align 8
  %93 = getelementptr inbounds double, double* %arrayptr254642, i64 %index1504
  %94 = bitcast double* %93 to <4 x double>*
  %wide.load1511 = load <4 x double>, <4 x double>* %94, align 8
  %95 = getelementptr inbounds double, double* %93, i64 4
  %96 = bitcast double* %95 to <4 x double>*
  %wide.load1512 = load <4 x double>, <4 x double>* %96, align 8
  %97 = fmul contract <4 x double> %wide.load1509, %wide.load1511
  %98 = fmul contract <4 x double> %wide.load1510, %wide.load1512
  %99 = fadd reassoc contract <4 x double> %vec.phi1505, %97
  %100 = fadd reassoc contract <4 x double> %vec.phi1506, %98
  %101 = fmul contract <4 x double> %wide.load1511, %wide.load1511
  %102 = fmul contract <4 x double> %wide.load1512, %wide.load1512
  %103 = fadd reassoc contract <4 x double> %vec.phi1507, %101
  %104 = fadd reassoc contract <4 x double> %vec.phi1508, %102
  %index.next1513 = add nuw i64 %index1504, 8
  %105 = icmp eq i64 %index.next1513, %n.vec1500
  br i1 %105, label %middle.block1495, label %vector.body1503

middle.block1495:                                 ; preds = %vector.body1503
  %bin.rdx1516 = fadd reassoc contract <4 x double> %104, %103
  %106 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1516)
  %bin.rdx1514 = fadd reassoc contract <4 x double> %100, %99
  %107 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1514)
  %cmp.n1502 = icmp eq i64 %arraylen241, %n.vec1500
  br i1 %cmp.n1502, label %L127, label %scalar.ph1496

scalar.ph1496:                                    ; preds = %middle.block1495, %L99.lr.ph
  %bc.resume.val1501 = phi i64 [ %n.vec1500, %middle.block1495 ], [ 0, %L99.lr.ph ]
  %bc.merge.rdx1515 = phi double [ %107, %middle.block1495 ], [ 0.000000e+00, %L99.lr.ph ]
  %bc.merge.rdx1517 = phi double [ %106, %middle.block1495 ], [ 0.000000e+00, %L99.lr.ph ]
  br label %L99

L99:                                              ; preds = %L99, %scalar.ph1496
  %value_phi246865 = phi i64 [ %bc.resume.val1501, %scalar.ph1496 ], [ %115, %L99 ]
  %value_phi245864 = phi double [ %bc.merge.rdx1515, %scalar.ph1496 ], [ %112, %L99 ]
  %value_phi244863 = phi double [ %bc.merge.rdx1517, %scalar.ph1496 ], [ %114, %L99 ]
  %108 = add i64 %85, %value_phi246865
  %109 = getelementptr inbounds double, double* %arrayptr251641, i64 %108
  %arrayref252 = load double, double* %109, align 8
  %110 = getelementptr inbounds double, double* %arrayptr254642, i64 %value_phi246865
  %arrayref255 = load double, double* %110, align 8
  %111 = fmul contract double %arrayref252, %arrayref255
  %112 = fadd reassoc contract double %value_phi245864, %111
  %113 = fmul contract double %arrayref255, %arrayref255
  %114 = fadd reassoc contract double %value_phi244863, %113
  %115 = add nuw nsw i64 %value_phi246865, 1
  %exitcond1039.not = icmp eq i64 %115, %arraylen241
  br i1 %exitcond1039.not, label %L127, label %L99

L127:                                             ; preds = %L99, %middle.block1495, %L86, %L57, %middle.block1518, %L43
  %value_phi38 = phi double [ 0.000000e+00, %L43 ], [ 0.000000e+00, %L86 ], [ %106, %middle.block1495 ], [ %70, %middle.block1518 ], [ %114, %L99 ], [ %81, %L57 ]
  %value_phi39 = phi double [ 0.000000e+00, %L43 ], [ 0.000000e+00, %L86 ], [ %107, %middle.block1495 ], [ %71, %middle.block1518 ], [ %112, %L99 ], [ %79, %L57 ]
  %value_phi40 = phi double [ 0.000000e+00, %L43 ], [ %arrayref19, %L86 ], [ %arrayref19, %middle.block1495 ], [ %72, %middle.block1518 ], [ %arrayref19, %L99 ], [ %77, %L57 ]
  %116 = fsub double %value_phi38, %value_phi38
  %117 = fcmp uno double %116, 0.000000e+00
  br i1 %117, label %L132, label %L134

L132:                                             ; preds = %L127
  %118 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %118, align 8
  %119 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 4
  store {}* %getfield10, {}** %119, align 16
  store {}* %getfield14, {}** %19, align 16
  call void @j__check_residual_755({}* nonnull %getfield14, i64 signext %arrayref)
  br label %L134

L134:                                             ; preds = %L132, %L127
  %120 = fcmp une double %value_phi40, 0.000000e+00
  br i1 %120, label %L175, label %L136

L136:                                             ; preds = %L134
  %getfield42 = load atomic {}*, {}** %37 unordered, align 8
  %121 = bitcast {}* %getfield42 to {}**
  %arraysize_ptr43 = getelementptr inbounds {}*, {}** %121, i64 3
  %122 = bitcast {}** %arraysize_ptr43 to i64*
  %arraysize44 = load i64, i64* %122, align 8
  %.not606.not = icmp eq i64 %arraysize44, 0
  br i1 %.not606.not, label %L175, label %L149.preheader

L149.preheader:                                   ; preds = %L136
  %arraysize_ptr57 = getelementptr inbounds {}*, {}** %121, i64 4
  %123 = bitcast {}** %arraysize_ptr57 to i64*
  %arraysize58 = load i64, i64* %123, align 8
  %inbounds59 = icmp ult i64 %41, %arraysize58
  %124 = mul i64 %arraysize44, %41
  %125 = bitcast {}* %getfield42 to double**
  %arrayptr64608 = load double*, double** %125, align 8
  %inbounds59.fr = freeze i1 %inbounds59
  br i1 %inbounds59.fr, label %ib.us, label %oob60

ib.us:                                            ; preds = %L155.us, %L149.preheader
  %value_phi49.us = phi i64 [ %130, %L155.us ], [ 1, %L149.preheader ]
  %126 = add nsw i64 %value_phi49.us, -1
  %127 = add i64 %124, %126
  %128 = getelementptr inbounds double, double* %arrayptr64608, i64 %127
  %arrayref65.us = load double, double* %128, align 8
  %129 = fcmp une double %arrayref65.us, 0.000000e+00
  br i1 %129, label %L171.split.us, label %L155.us

L155.us:                                          ; preds = %ib.us
  %130 = add nuw nsw i64 %value_phi49.us, 1
  %131 = icmp ult i64 %value_phi49.us, %arraysize44
  br i1 %131, label %ib.us, label %L175

L171.split.us:                                    ; preds = %ib.us
  store {}* inttoptr (i64 135794567260688 to {}*), {}** %6, align 8
  %132 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %132)
  unreachable

L175:                                             ; preds = %L155.us, %L136, %L134
  %133 = fsub double %value_phi40, %value_phi40
  %134 = fcmp uno double %133, 0.000000e+00
  br i1 %134, label %L488, label %L180

L180:                                             ; preds = %L175
  %getfield72 = load atomic {}*, {}** %25 unordered, align 8
  %135 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr74 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %135, i64 0, i32 1
  %arraylen75 = load i64, i64* %arraylen_ptr74, align 8
  %.not610 = icmp ult i64 %41, %arraylen75
  br i1 %.not610, label %L194, label %L191

L191:                                             ; preds = %L180
  store i64 %arrayref, i64* %26, align 8
  store {}* %getfield72, {}** %19, align 16
  call void @j_throw_boundserror_749({}* nonnull %getfield72, [1 x i64]* nocapture readonly %newstruct73) #3
  unreachable

L194:                                             ; preds = %L180
  %136 = bitcast {}* %getfield72 to i64**
  %arrayptr80611 = load i64*, i64** %136, align 8
  %137 = getelementptr inbounds i64, i64* %arrayptr80611, i64 %41
  %arrayref81 = load i64, i64* %137, align 8
  %.not612 = icmp eq i64 %arrayref81, 0
  br i1 %.not612, label %L204, label %L199

L199:                                             ; preds = %L194
  %138 = bitcast {}* %0 to double***
  %getfield2321849 = load atomic double**, double*** %138 unordered, align 8
  %139 = add i64 %arrayref81, -1
  %arrayptr234638 = load double*, double** %getfield2321849, align 8
  %140 = getelementptr inbounds double, double* %arrayptr234638, i64 %139
  %arrayref235 = load double, double* %140, align 8
  br label %L204

L204:                                             ; preds = %L199, %L194
  %value_phi82 = phi double [ %arrayref235, %L199 ], [ 0.000000e+00, %L194 ]
  br i1 %120, label %L208, label %L206

L206:                                             ; preds = %L204
  %141 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %141, align 8
  %142 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 4
  store {}* %getfield10, {}** %142, align 16
  %143 = call double @j__coordinate_minimizer_747({ double }* nocapture nonnull readonly %2, double %value_phi82, i64 signext %arrayref)
  br label %L406

L208:                                             ; preds = %L204
  %getfield174 = load atomic {}*, {}** %23 unordered, align 8
  %144 = bitcast {}* %getfield174 to i8*
  %getfield_addr175 = getelementptr inbounds i8, i8* %144, i64 24
  %145 = bitcast i8* %getfield_addr175 to {}**
  %getfield176 = load atomic {}*, {}** %145 unordered, align 8
  %146 = bitcast {}* %getfield176 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr177 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %146, i64 0, i32 1
  %arraylen178 = load i64, i64* %arraylen_ptr177, align 8
  %147 = sitofp i64 %arraylen178 to double
  %148 = fmul double %147, 0x350000000000000
  %149 = fcmp ole double %148, %value_phi40
  %150 = fcmp ord double %116, 0.000000e+00
  %151 = fcmp ole double %148, %value_phi38
  %152 = and i1 %150, %151
  %153 = and i1 %149, %152
  br i1 %153, label %L227, label %L403

L227:                                             ; preds = %L208
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %154 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %154, label %L233, label %L231

L231:                                             ; preds = %L227
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %value_phi40) #3
  unreachable

L233:                                             ; preds = %L227
  %155 = call double @llvm.sqrt.f64(double %value_phi40)
  %156 = fcmp ugt double %155, %aggregate_load_box.sroa.0.0.copyload
  br i1 %156, label %L238, label %L406

L238:                                             ; preds = %L233
  %157 = fdiv double %value_phi39, %value_phi40
  %158 = fadd double %157, %value_phi82
  %159 = fmul double %value_phi39, %157
  %160 = fsub double %value_phi38, %159
  %161 = fmul double %value_phi38, 6.250000e-02
  %162 = fcmp uge double %160, %161
  br i1 %162, label %L293, label %L245

L245:                                             ; preds = %L238
  %.not629 = icmp eq i64 %arraylen178, 0
  br i1 %.not629, label %L282, label %L259.lr.ph

L259.lr.ph:                                       ; preds = %L245
  %163 = bitcast {}* %getfield174 to {}**
  %getfield183 = load atomic {}*, {}** %163 unordered, align 8
  %164 = bitcast {}* %getfield176 to double**
  %arrayptr193631 = load double*, double** %164, align 8
  %165 = bitcast {}* %getfield183 to {}**
  %arraysize_ptr195 = getelementptr inbounds {}*, {}** %165, i64 3
  %166 = bitcast {}** %arraysize_ptr195 to i64*
  %arraysize196 = load i64, i64* %166, align 8
  %167 = mul i64 %arraysize196, %41
  %168 = bitcast {}* %getfield183 to double**
  %arrayptr199632 = load double*, double** %168, align 8
  %min.iters.check1465 = icmp ult i64 %arraylen178, 16
  br i1 %min.iters.check1465, label %scalar.ph1464, label %vector.ph1466

vector.ph1466:                                    ; preds = %L259.lr.ph
  %n.vec1468 = and i64 %arraylen178, 9223372036854775792
  %broadcast.splatinsert1484 = insertelement <4 x double> poison, double %157, i64 0
  %broadcast.splat1485 = shufflevector <4 x double> %broadcast.splatinsert1484, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1471

vector.body1471:                                  ; preds = %vector.body1471, %vector.ph1466
  %index1472 = phi i64 [ 0, %vector.ph1466 ], [ %index.next1492, %vector.body1471 ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1466 ], [ %198, %vector.body1471 ]
  %vec.phi1473 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1466 ], [ %199, %vector.body1471 ]
  %vec.phi1474 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1466 ], [ %200, %vector.body1471 ]
  %vec.phi1475 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1466 ], [ %201, %vector.body1471 ]
  %169 = getelementptr inbounds double, double* %arrayptr193631, i64 %index1472
  %170 = bitcast double* %169 to <4 x double>*
  %wide.load1476 = load <4 x double>, <4 x double>* %170, align 8
  %171 = getelementptr inbounds double, double* %169, i64 4
  %172 = bitcast double* %171 to <4 x double>*
  %wide.load1477 = load <4 x double>, <4 x double>* %172, align 8
  %173 = getelementptr inbounds double, double* %169, i64 8
  %174 = bitcast double* %173 to <4 x double>*
  %wide.load1478 = load <4 x double>, <4 x double>* %174, align 8
  %175 = getelementptr inbounds double, double* %169, i64 12
  %176 = bitcast double* %175 to <4 x double>*
  %wide.load1479 = load <4 x double>, <4 x double>* %176, align 8
  %177 = add i64 %167, %index1472
  %178 = getelementptr inbounds double, double* %arrayptr199632, i64 %177
  %179 = bitcast double* %178 to <4 x double>*
  %wide.load1480 = load <4 x double>, <4 x double>* %179, align 8
  %180 = getelementptr inbounds double, double* %178, i64 4
  %181 = bitcast double* %180 to <4 x double>*
  %wide.load1481 = load <4 x double>, <4 x double>* %181, align 8
  %182 = getelementptr inbounds double, double* %178, i64 8
  %183 = bitcast double* %182 to <4 x double>*
  %wide.load1482 = load <4 x double>, <4 x double>* %183, align 8
  %184 = getelementptr inbounds double, double* %178, i64 12
  %185 = bitcast double* %184 to <4 x double>*
  %wide.load1483 = load <4 x double>, <4 x double>* %185, align 8
  %186 = fmul <4 x double> %broadcast.splat1485, %wide.load1480
  %187 = fmul <4 x double> %broadcast.splat1485, %wide.load1481
  %188 = fmul <4 x double> %broadcast.splat1485, %wide.load1482
  %189 = fmul <4 x double> %broadcast.splat1485, %wide.load1483
  %190 = fsub <4 x double> %wide.load1476, %186
  %191 = fsub <4 x double> %wide.load1477, %187
  %192 = fsub <4 x double> %wide.load1478, %188
  %193 = fsub <4 x double> %wide.load1479, %189
  %194 = fmul contract <4 x double> %190, %190
  %195 = fmul contract <4 x double> %191, %191
  %196 = fmul contract <4 x double> %192, %192
  %197 = fmul contract <4 x double> %193, %193
  %198 = fadd reassoc contract <4 x double> %vec.phi, %194
  %199 = fadd reassoc contract <4 x double> %vec.phi1473, %195
  %200 = fadd reassoc contract <4 x double> %vec.phi1474, %196
  %201 = fadd reassoc contract <4 x double> %vec.phi1475, %197
  %index.next1492 = add nuw i64 %index1472, 16
  %202 = icmp eq i64 %index.next1492, %n.vec1468
  br i1 %202, label %middle.block1463, label %vector.body1471

middle.block1463:                                 ; preds = %vector.body1471
  %bin.rdx = fadd reassoc contract <4 x double> %199, %198
  %bin.rdx1493 = fadd reassoc contract <4 x double> %200, %bin.rdx
  %bin.rdx1494 = fadd reassoc contract <4 x double> %201, %bin.rdx1493
  %203 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1494)
  %cmp.n1470 = icmp eq i64 %arraylen178, %n.vec1468
  br i1 %cmp.n1470, label %L282, label %scalar.ph1464

scalar.ph1464:                                    ; preds = %middle.block1463, %L259.lr.ph
  %bc.resume.val1469 = phi i64 [ %n.vec1468, %middle.block1463 ], [ 0, %L259.lr.ph ]
  %bc.merge.rdx = phi double [ %203, %middle.block1463 ], [ 0.000000e+00, %L259.lr.ph ]
  br label %L259

L259:                                             ; preds = %L259, %scalar.ph1464
  %value_phi191870 = phi i64 [ %bc.resume.val1469, %scalar.ph1464 ], [ %211, %L259 ]
  %value_phi190869 = phi double [ %bc.merge.rdx, %scalar.ph1464 ], [ %210, %L259 ]
  %204 = getelementptr inbounds double, double* %arrayptr193631, i64 %value_phi191870
  %arrayref194 = load double, double* %204, align 8
  %205 = add i64 %167, %value_phi191870
  %206 = getelementptr inbounds double, double* %arrayptr199632, i64 %205
  %arrayref200 = load double, double* %206, align 8
  %207 = fmul double %157, %arrayref200
  %208 = fsub double %arrayref194, %207
  %209 = fmul contract double %208, %208
  %210 = fadd reassoc contract double %value_phi190869, %209
  %211 = add nuw nsw i64 %value_phi191870, 1
  %exitcond1040.not = icmp eq i64 %211, %arraylen178
  br i1 %exitcond1040.not, label %L282, label %L259

L282:                                             ; preds = %L259, %middle.block1463, %L245
  %value_phi202 = phi double [ 0.000000e+00, %L245 ], [ %203, %middle.block1463 ], [ %210, %L259 ]
  %212 = fsub double %value_phi202, %value_phi202
  %213 = fcmp uno double %212, 0.000000e+00
  %214 = fcmp ugt double %148, %value_phi202
  %215 = or i1 %214, %213
  br i1 %215, label %L291, label %L293

L291:                                             ; preds = %L282
  %216 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %216, align 8
  %217 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 4
  store {}* %getfield10, {}** %217, align 16
  %218 = call double @j__sqrt_offrange_step_753({}* nonnull %1, double %value_phi82, i64 signext %arrayref)
  br label %L406

L293:                                             ; preds = %L282, %L238
  %value_phi204 = phi double [ %160, %L238 ], [ %value_phi202, %L282 ]
  %219 = fcmp uge double %value_phi204, 0.000000e+00
  br i1 %219, label %L298, label %L296

L296:                                             ; preds = %L293
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %value_phi204) #3
  unreachable

L298:                                             ; preds = %L293
  %220 = call double @llvm.sqrt.f64(double %value_phi204)
  %221 = fsub double %155, %aggregate_load_box.sroa.0.0.copyload
  %222 = fcmp uge double %221, 0.000000e+00
  br i1 %222, label %L305, label %L303

L303:                                             ; preds = %L298
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %221) #3
  unreachable

L305:                                             ; preds = %L298
  %223 = fadd double %155, %aggregate_load_box.sroa.0.0.copyload
  %224 = fcmp uge double %223, 0.000000e+00
  br i1 %224, label %L312, label %L310

L310:                                             ; preds = %L305
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %223) #3
  unreachable

L312:                                             ; preds = %L305
  %225 = call double @llvm.sqrt.f64(double %221)
  %226 = call double @llvm.sqrt.f64(double %223)
  %227 = fmul double %225, %226
  %228 = fmul double %155, %227
  %229 = fdiv double %220, %228
  %230 = fmul double %aggregate_load_box.sroa.0.0.copyload, %229
  %231 = fcmp oge double %228, 0x10000000000000
  %232 = fcmp oge double %229, 0x10000000000000
  %233 = fcmp ole double %229, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %232, %233
  %234 = and i1 %231, %narrow
  %235 = fcmp oge double %230, 0x10000000000000
  %236 = fcmp ole double %230, 0x7FEFFFFFFFFFFFFF
  %narrow633 = and i1 %235, %236
  %237 = and i1 %234, %narrow633
  br i1 %237, label %L346, label %L401

L346:                                             ; preds = %L312
  %238 = fneg double %230
  %.inv635 = fcmp ogt double %158, %238
  %239 = select i1 %.inv635, double %158, double %238
  %.inv636 = fcmp olt double %239, %230
  %240 = select i1 %.inv636, double %239, double %230
  %241 = fsub double %158, %240
  %242 = fadd double %241, 0.000000e+00
  br label %L406

L401:                                             ; preds = %L312
  %243 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %243, align 8
  %244 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 4
  store {}* %getfield10, {}** %244, align 16
  %245 = call double @j__sqrt_band_step_752(double %158, double %155, double %aggregate_load_box.sroa.0.0.copyload, double %220, i64 signext 0)
  br label %L406

L403:                                             ; preds = %L208
  %246 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %246, align 8
  %247 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 4
  store {}* %getfield10, {}** %247, align 16
  %248 = call double @j__sqrt_offrange_step_753({}* nonnull %1, double %value_phi82, i64 signext %arrayref)
  br label %L406

L406:                                             ; preds = %L403, %L401, %L346, %L291, %L233, %L206
  %value_phi83 = phi double [ %143, %L206 ], [ %218, %L291 ], [ %245, %L401 ], [ %248, %L403 ], [ 0.000000e+00, %L233 ], [ %242, %L346 ]
  %getfield85 = load atomic {}*, {}** %40 unordered, align 8
  %249 = bitcast {}* %getfield85 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr86 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %249, i64 0, i32 1
  %arraylen87 = load i64, i64* %arraylen_ptr86, align 8
  %inbounds88 = icmp ult i64 %41, %arraylen87
  br i1 %inbounds88, label %idxend91, label %oob89

L414:                                             ; preds = %idxend91
  %getfield107 = load atomic {}*, {}** %25 unordered, align 8
  %250 = bitcast {}* %getfield107 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr109 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %250, i64 0, i32 1
  %arraylen110 = load i64, i64* %arraylen_ptr109, align 8
  %.not617 = icmp ult i64 %41, %arraylen110
  br i1 %.not617, label %L428, label %L425

L425:                                             ; preds = %L414
  store i64 %arrayref, i64* %30, align 8
  store {}* %getfield107, {}** %19, align 16
  call void @j_throw_boundserror_749({}* nonnull %getfield107, [1 x i64]* nocapture readonly %newstruct108) #3
  unreachable

L428:                                             ; preds = %L414
  %251 = bitcast {}* %getfield107 to i64**
  %arrayptr115618 = load i64*, i64** %251, align 8
  %252 = getelementptr inbounds i64, i64* %arrayptr115618, i64 %41
  %arrayref116 = load i64, i64* %252, align 8
  %.not619 = icmp eq i64 %arrayref116, 0
  br i1 %.not619, label %L436, label %L433

L433:                                             ; preds = %L428
  %253 = bitcast {}* %0 to double***
  %getfield1181850 = load atomic double**, double*** %253 unordered, align 8
  %254 = add i64 %arrayref116, -1
  %arrayptr120620 = load double*, double** %getfield1181850, align 8
  %255 = getelementptr inbounds double, double* %arrayptr120620, i64 %254
  store double %value_phi83, double* %255, align 8
  br label %L453

L436:                                             ; preds = %L428
  %256 = fcmp oeq double %value_phi83, 0.000000e+00
  br i1 %256, label %L453, label %L439

L439:                                             ; preds = %L436
  %257 = load i64, i64* %32, align 8
  %258 = add i64 %257, 1
  store i64 %258, i64* %32, align 8
  %getfield143 = load atomic {}*, {}** %27 unordered, align 8
  %259 = bitcast {}* %getfield143 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr144 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %259, i64 0, i32 1
  %arraylen145 = load i64, i64* %arraylen_ptr144, align 8
  %inbounds146 = icmp ult i64 %257, %arraylen145
  br i1 %inbounds146, label %idxend149, label %oob147

L453:                                             ; preds = %idxend169, %L436, %L433
  %getfield122 = load atomic {}*, {}** %39 unordered, align 8
  %260 = bitcast {}* %getfield122 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr125 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %260, i64 0, i32 1
  %arraylen126 = load i64, i64* %arraylen_ptr125, align 8
  %.not621 = icmp eq i64 %arraylen126, 0
  br i1 %.not621, label %L490, label %L466.lr.ph

L466.lr.ph:                                       ; preds = %L453
  %getfield124 = load atomic {}*, {}** %37 unordered, align 8
  %261 = bitcast {}* %getfield122 to double**
  %arrayptr131623 = load double*, double** %261, align 8
  %262 = bitcast {}* %getfield124 to {}**
  %arraysize_ptr133 = getelementptr inbounds {}*, {}** %262, i64 3
  %263 = bitcast {}** %arraysize_ptr133 to i64*
  %arraysize134 = load i64, i64* %263, align 8
  %264 = mul i64 %arraysize134, %41
  %265 = bitcast {}* %getfield124 to double**
  %arrayptr137624 = load double*, double** %265, align 8
  %min.iters.check = icmp ult i64 %arraylen126, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.memcheck

vector.memcheck:                                  ; preds = %L466.lr.ph
  %scevgep = getelementptr double, double* %arrayptr131623, i64 %arraylen126
  %scevgep1446 = getelementptr double, double* %arrayptr137624, i64 %264
  %266 = add i64 %arraylen126, %264
  %scevgep1448 = getelementptr double, double* %arrayptr137624, i64 %266
  %bound0 = icmp ult double* %arrayptr131623, %scevgep1448
  %bound1 = icmp ult double* %scevgep1446, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.vec = and i64 %arraylen126, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %603, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %267 = getelementptr inbounds double, double* %arrayptr131623, i64 %index
  %268 = bitcast double* %267 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %268, align 8
  %269 = getelementptr inbounds double, double* %267, i64 4
  %270 = bitcast double* %269 to <4 x double>*
  %wide.load1450 = load <4 x double>, <4 x double>* %270, align 8
  %271 = getelementptr inbounds double, double* %267, i64 8
  %272 = bitcast double* %271 to <4 x double>*
  %wide.load1451 = load <4 x double>, <4 x double>* %272, align 8
  %273 = getelementptr inbounds double, double* %267, i64 12
  %274 = bitcast double* %273 to <4 x double>*
  %wide.load1452 = load <4 x double>, <4 x double>* %274, align 8
  %275 = add i64 %264, %index
  %276 = getelementptr inbounds double, double* %arrayptr137624, i64 %275
  %277 = bitcast double* %276 to <4 x double>*
  %wide.load1453 = load <4 x double>, <4 x double>* %277, align 8
  %278 = getelementptr inbounds double, double* %276, i64 4
  %279 = bitcast double* %278 to <4 x double>*
  %wide.load1454 = load <4 x double>, <4 x double>* %279, align 8
  %280 = getelementptr inbounds double, double* %276, i64 8
  %281 = bitcast double* %280 to <4 x double>*
  %wide.load1455 = load <4 x double>, <4 x double>* %281, align 8
  %282 = getelementptr inbounds double, double* %276, i64 12
  %283 = bitcast double* %282 to <4 x double>*
  %wide.load1456 = load <4 x double>, <4 x double>* %283, align 8
  %284 = fmul <4 x double> %broadcast.splat, %wide.load1453
  %285 = fmul <4 x double> %broadcast.splat, %wide.load1454
  %286 = fmul <4 x double> %broadcast.splat, %wide.load1455
  %287 = fmul <4 x double> %broadcast.splat, %wide.load1456
  %288 = fsub <4 x double> %wide.load, %284
  %289 = fsub <4 x double> %wide.load1450, %285
  %290 = fsub <4 x double> %wide.load1451, %286
  %291 = fsub <4 x double> %wide.load1452, %287
  store <4 x double> %288, <4 x double>* %268, align 8
  store <4 x double> %289, <4 x double>* %270, align 8
  store <4 x double> %290, <4 x double>* %272, align 8
  store <4 x double> %291, <4 x double>* %274, align 8
  %index.next = add nuw i64 %index, 16
  %292 = icmp eq i64 %index.next, %n.vec
  br i1 %292, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %arraylen126, %n.vec
  br i1 %cmp.n, label %L490, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %vector.memcheck, %L466.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L466.lr.ph ], [ 0, %vector.memcheck ]
  br label %L466

L466:                                             ; preds = %L466, %scalar.ph
  %value_phi129873 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %298, %L466 ]
  %293 = getelementptr inbounds double, double* %arrayptr131623, i64 %value_phi129873
  %arrayref132 = load double, double* %293, align 8
  %294 = add i64 %264, %value_phi129873
  %295 = getelementptr inbounds double, double* %arrayptr137624, i64 %294
  %arrayref138 = load double, double* %295, align 8
  %296 = fmul double %603, %arrayref138
  %297 = fsub double %arrayref132, %296
  store double %297, double* %293, align 8
  %298 = add nuw nsw i64 %value_phi129873, 1
  %exitcond1041.not = icmp eq i64 %298, %arraylen126
  br i1 %exitcond1041.not, label %L490, label %L466

L488:                                             ; preds = %L175
  call void @j__refuse_curvature_754(i64 signext %arrayref) #3
  unreachable

L490:                                             ; preds = %idxend91, %L466, %middle.block, %L453
  %arrayref936 = phi i64 [ %arrayref, %L453 ], [ %arrayref937, %idxend91 ], [ %arrayref, %middle.block ], [ %arrayref, %L466 ]
  %299 = call double @llvm.fabs.f64(double %603)
  %300 = fcmp oeq double %603, 0.000000e+00
  %or.cond = select i1 %.not614, i1 true, i1 %300
  br i1 %or.cond, label %L501, label %L496

L496:                                             ; preds = %L490
  %getfield96 = load atomic {}*, {}** %23 unordered, align 8
  %301 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %20, {}** %301, align 8
  store {}* %getfield96, {}** %19, align 16
  %302 = call double @j_coordinate_scale_748({}* nonnull %getfield96, {}* nonnull %0, i64 signext %arrayref)
  %303 = fmul double %299, %302
  br label %L501

L501:                                             ; preds = %L496, %L490
  %value_phi97 = phi double [ %303, %L496 ], [ %299, %L490 ]
  %304 = fsub double %value_phi97, %value_phi97
  %305 = fcmp uno double %304, 0.000000e+00
  br i1 %305, label %L507, label %L510

L507:                                             ; preds = %L501
  store {}* inttoptr (i64 135794568219280 to {}*), {}** %6, align 8
  %306 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %306)
  unreachable

L510:                                             ; preds = %L501
  %.inv615 = fcmp olt double %value_phi7, %value_phi97
  %307 = select i1 %.inv615, double %value_phi97, double %value_phi7
  %.not616.not = icmp eq i64 %value_phi5, %value_phi
  %308 = add nuw i64 %value_phi5, 1
  br i1 %.not616.not, label %L1045.loopexit691, label %L22

L527:                                             ; preds = %top
  %unbox262 = load i64, i64* %14, align 8
  %309 = call i64 @llvm.smax.i64(i64 %unbox262, i64 0)
  %310 = icmp slt i64 %unbox262, 1
  br i1 %310, label %L1045, label %L543.preheader

L543.preheader:                                   ; preds = %L527
  %311 = bitcast {}* %1 to {}**
  %312 = bitcast {}* %0 to i8*
  %getfield_addr347 = getelementptr inbounds i8, i8* %312, i64 16
  %313 = bitcast i8* %getfield_addr347 to {}**
  %314 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct349, i64 0, i64 0
  %315 = bitcast {}* %0 to {}**
  %316 = bitcast {}* %1 to i8*
  %317 = getelementptr inbounds i8, i8* %316, i64 8
  %aggregate_load_box453.sroa.0.0..sroa_idx = bitcast i8* %317 to double*
  %318 = getelementptr inbounds [1 x i64], [1 x i64]* %newstruct382, i64 0, i64 0
  %319 = getelementptr inbounds i8, i8* %312, i64 24
  %320 = bitcast i8* %319 to i64*
  %getfield_addr426 = getelementptr inbounds i8, i8* %312, i64 8
  %321 = bitcast i8* %getfield_addr426 to {}**
  %322 = and i8 %4, 1
  %.not657 = icmp eq i8 %322, 0
  br label %L543

L543:                                             ; preds = %L1030, %L543.preheader
  %indvar = phi i64 [ 0, %L543.preheader ], [ %indvar.next, %L1030 ]
  %value_phi267998 = phi i64 [ undef, %L543.preheader ], [ %value_phi267997, %L1030 ]
  %value_phi267 = phi i64 [ 1, %L543.preheader ], [ %593, %L1030 ]
  %value_phi269 = phi double [ 0.000000e+00, %L543.preheader ], [ %592, %L1030 ]
  %323 = shl i64 %indvar, 3
  %getfield272 = load atomic {}*, {}** %311 unordered, align 8
  %324 = bitcast {}* %getfield272 to {}**
  %getfield274 = load atomic {}*, {}** %324 unordered, align 8
  %325 = bitcast {}* %getfield272 to i8*
  %getfield_addr275 = getelementptr inbounds i8, i8* %325, i64 24
  %326 = bitcast i8* %getfield_addr275 to {}**
  %getfield276 = load atomic {}*, {}** %326 unordered, align 8
  %getfield_addr277 = getelementptr inbounds i8, i8* %325, i64 32
  %327 = bitcast i8* %getfield_addr277 to {}**
  %getfield278 = load atomic {}*, {}** %327 unordered, align 8
  %328 = add nsw i64 %value_phi267, -1
  %329 = bitcast {}* %getfield278 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr279 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %329, i64 0, i32 1
  %arraylen280 = load i64, i64* %arraylen_ptr279, align 8
  %inbounds281 = icmp ult i64 %328, %arraylen280
  br i1 %inbounds281, label %idxend284, label %oob282

L563:                                             ; preds = %idxend284
  br i1 %.not683, label %L647, label %L577.lr.ph

L577.lr.ph:                                       ; preds = %L563
  %330 = bitcast {}* %getfield274 to {}**
  %arraysize_ptr296 = getelementptr inbounds {}*, {}** %330, i64 3
  %331 = bitcast {}** %arraysize_ptr296 to i64*
  %arraysize297 = load i64, i64* %331, align 8
  %332 = mul i64 %arraysize297, %328
  %333 = bitcast {}* %getfield274 to double**
  %arrayptr300647 = load double*, double** %333, align 8
  %334 = bitcast {}* %getfield276 to double**
  %arrayptr303648 = load double*, double** %334, align 8
  %min.iters.check1643 = icmp ult i64 %arraylen517, 8
  br i1 %min.iters.check1643, label %scalar.ph1642, label %vector.ph1644

vector.ph1644:                                    ; preds = %L577.lr.ph
  %n.vec1646 = and i64 %arraylen517, 9223372036854775800
  br label %vector.body1649

vector.body1649:                                  ; preds = %vector.body1649, %vector.ph1644
  %index1650 = phi i64 [ 0, %vector.ph1644 ], [ %index.next1661, %vector.body1649 ]
  %vec.phi1651 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %346, %vector.body1649 ]
  %vec.phi1652 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %347, %vector.body1649 ]
  %vec.phi1653 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %350, %vector.body1649 ]
  %vec.phi1654 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %351, %vector.body1649 ]
  %vec.phi1655 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %354, %vector.body1649 ]
  %vec.phi1656 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1644 ], [ %355, %vector.body1649 ]
  %335 = add i64 %332, %index1650
  %336 = getelementptr inbounds double, double* %arrayptr300647, i64 %335
  %337 = bitcast double* %336 to <4 x double>*
  %wide.load1657 = load <4 x double>, <4 x double>* %337, align 8
  %338 = getelementptr inbounds double, double* %336, i64 4
  %339 = bitcast double* %338 to <4 x double>*
  %wide.load1658 = load <4 x double>, <4 x double>* %339, align 8
  %340 = getelementptr inbounds double, double* %arrayptr303648, i64 %index1650
  %341 = bitcast double* %340 to <4 x double>*
  %wide.load1659 = load <4 x double>, <4 x double>* %341, align 8
  %342 = getelementptr inbounds double, double* %340, i64 4
  %343 = bitcast double* %342 to <4 x double>*
  %wide.load1660 = load <4 x double>, <4 x double>* %343, align 8
  %344 = fmul contract <4 x double> %wide.load1657, %wide.load1657
  %345 = fmul contract <4 x double> %wide.load1658, %wide.load1658
  %346 = fadd reassoc contract <4 x double> %vec.phi1651, %344
  %347 = fadd reassoc contract <4 x double> %vec.phi1652, %345
  %348 = fmul contract <4 x double> %wide.load1657, %wide.load1659
  %349 = fmul contract <4 x double> %wide.load1658, %wide.load1660
  %350 = fadd reassoc contract <4 x double> %vec.phi1653, %348
  %351 = fadd reassoc contract <4 x double> %vec.phi1654, %349
  %352 = fmul contract <4 x double> %wide.load1659, %wide.load1659
  %353 = fmul contract <4 x double> %wide.load1660, %wide.load1660
  %354 = fadd reassoc contract <4 x double> %vec.phi1655, %352
  %355 = fadd reassoc contract <4 x double> %vec.phi1656, %353
  %index.next1661 = add nuw i64 %index1650, 8
  %356 = icmp eq i64 %index.next1661, %n.vec1646
  br i1 %356, label %middle.block1641, label %vector.body1649

middle.block1641:                                 ; preds = %vector.body1649
  %bin.rdx1666 = fadd reassoc contract <4 x double> %355, %354
  %357 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1666)
  %bin.rdx1664 = fadd reassoc contract <4 x double> %351, %350
  %358 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1664)
  %bin.rdx1662 = fadd reassoc contract <4 x double> %347, %346
  %359 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1662)
  %cmp.n1648 = icmp eq i64 %arraylen517, %n.vec1646
  br i1 %cmp.n1648, label %L647, label %scalar.ph1642

scalar.ph1642:                                    ; preds = %middle.block1641, %L577.lr.ph
  %bc.resume.val1647 = phi i64 [ %n.vec1646, %middle.block1641 ], [ 0, %L577.lr.ph ]
  %bc.merge.rdx1663 = phi double [ %359, %middle.block1641 ], [ 0.000000e+00, %L577.lr.ph ]
  %bc.merge.rdx1665 = phi double [ %358, %middle.block1641 ], [ 0.000000e+00, %L577.lr.ph ]
  %bc.merge.rdx1667 = phi double [ %357, %middle.block1641 ], [ 0.000000e+00, %L577.lr.ph ]
  br label %L577

L577:                                             ; preds = %L577, %scalar.ph1642
  %value_phi295878 = phi double [ %bc.merge.rdx1663, %scalar.ph1642 ], [ %364, %L577 ]
  %value_phi294877 = phi i64 [ %bc.resume.val1647, %scalar.ph1642 ], [ %369, %L577 ]
  %value_phi293876 = phi double [ %bc.merge.rdx1665, %scalar.ph1642 ], [ %366, %L577 ]
  %value_phi292875 = phi double [ %bc.merge.rdx1667, %scalar.ph1642 ], [ %368, %L577 ]
  %360 = add i64 %332, %value_phi294877
  %361 = getelementptr inbounds double, double* %arrayptr300647, i64 %360
  %arrayref301 = load double, double* %361, align 8
  %362 = getelementptr inbounds double, double* %arrayptr303648, i64 %value_phi294877
  %arrayref304 = load double, double* %362, align 8
  %363 = fmul contract double %arrayref301, %arrayref301
  %364 = fadd reassoc contract double %value_phi295878, %363
  %365 = fmul contract double %arrayref301, %arrayref304
  %366 = fadd reassoc contract double %value_phi293876, %365
  %367 = fmul contract double %arrayref304, %arrayref304
  %368 = fadd reassoc contract double %value_phi292875, %367
  %369 = add nuw nsw i64 %value_phi294877, 1
  %exitcond1042.not = icmp eq i64 %369, %arraylen517
  br i1 %exitcond1042.not, label %L647, label %L577

L606:                                             ; preds = %idxend284
  br i1 %.not683, label %L647, label %L619.lr.ph

L619.lr.ph:                                       ; preds = %L606
  %370 = bitcast {}* %getfield274 to {}**
  %arraysize_ptr523 = getelementptr inbounds {}*, {}** %370, i64 3
  %371 = bitcast {}** %arraysize_ptr523 to i64*
  %arraysize524 = load i64, i64* %371, align 8
  %372 = mul i64 %arraysize524, %328
  %373 = bitcast {}* %getfield274 to double**
  %arrayptr527685 = load double*, double** %373, align 8
  %374 = bitcast {}* %getfield276 to double**
  %arrayptr530686 = load double*, double** %374, align 8
  %min.iters.check1620 = icmp ult i64 %arraylen517, 8
  br i1 %min.iters.check1620, label %scalar.ph1619, label %vector.ph1621

vector.ph1621:                                    ; preds = %L619.lr.ph
  %n.vec1623 = and i64 %arraylen517, 9223372036854775800
  br label %vector.body1626

vector.body1626:                                  ; preds = %vector.body1626, %vector.ph1621
  %index1627 = phi i64 [ 0, %vector.ph1621 ], [ %index.next1636, %vector.body1626 ]
  %vec.phi1628 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1621 ], [ %386, %vector.body1626 ]
  %vec.phi1629 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1621 ], [ %387, %vector.body1626 ]
  %vec.phi1630 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1621 ], [ %390, %vector.body1626 ]
  %vec.phi1631 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1621 ], [ %391, %vector.body1626 ]
  %375 = add i64 %372, %index1627
  %376 = getelementptr inbounds double, double* %arrayptr527685, i64 %375
  %377 = bitcast double* %376 to <4 x double>*
  %wide.load1632 = load <4 x double>, <4 x double>* %377, align 8
  %378 = getelementptr inbounds double, double* %376, i64 4
  %379 = bitcast double* %378 to <4 x double>*
  %wide.load1633 = load <4 x double>, <4 x double>* %379, align 8
  %380 = getelementptr inbounds double, double* %arrayptr530686, i64 %index1627
  %381 = bitcast double* %380 to <4 x double>*
  %wide.load1634 = load <4 x double>, <4 x double>* %381, align 8
  %382 = getelementptr inbounds double, double* %380, i64 4
  %383 = bitcast double* %382 to <4 x double>*
  %wide.load1635 = load <4 x double>, <4 x double>* %383, align 8
  %384 = fmul contract <4 x double> %wide.load1632, %wide.load1634
  %385 = fmul contract <4 x double> %wide.load1633, %wide.load1635
  %386 = fadd reassoc contract <4 x double> %vec.phi1628, %384
  %387 = fadd reassoc contract <4 x double> %vec.phi1629, %385
  %388 = fmul contract <4 x double> %wide.load1634, %wide.load1634
  %389 = fmul contract <4 x double> %wide.load1635, %wide.load1635
  %390 = fadd reassoc contract <4 x double> %vec.phi1630, %388
  %391 = fadd reassoc contract <4 x double> %vec.phi1631, %389
  %index.next1636 = add nuw i64 %index1627, 8
  %392 = icmp eq i64 %index.next1636, %n.vec1623
  br i1 %392, label %middle.block1618, label %vector.body1626

middle.block1618:                                 ; preds = %vector.body1626
  %bin.rdx1639 = fadd reassoc contract <4 x double> %391, %390
  %393 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1639)
  %bin.rdx1637 = fadd reassoc contract <4 x double> %387, %386
  %394 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1637)
  %cmp.n1625 = icmp eq i64 %arraylen517, %n.vec1623
  br i1 %cmp.n1625, label %L647, label %scalar.ph1619

scalar.ph1619:                                    ; preds = %middle.block1618, %L619.lr.ph
  %bc.resume.val1624 = phi i64 [ %n.vec1623, %middle.block1618 ], [ 0, %L619.lr.ph ]
  %bc.merge.rdx1638 = phi double [ %394, %middle.block1618 ], [ 0.000000e+00, %L619.lr.ph ]
  %bc.merge.rdx1640 = phi double [ %393, %middle.block1618 ], [ 0.000000e+00, %L619.lr.ph ]
  br label %L619

L619:                                             ; preds = %L619, %scalar.ph1619
  %value_phi522885 = phi i64 [ %bc.resume.val1624, %scalar.ph1619 ], [ %402, %L619 ]
  %value_phi521884 = phi double [ %bc.merge.rdx1638, %scalar.ph1619 ], [ %399, %L619 ]
  %value_phi520883 = phi double [ %bc.merge.rdx1640, %scalar.ph1619 ], [ %401, %L619 ]
  %395 = add i64 %372, %value_phi522885
  %396 = getelementptr inbounds double, double* %arrayptr527685, i64 %395
  %arrayref528 = load double, double* %396, align 8
  %397 = getelementptr inbounds double, double* %arrayptr530686, i64 %value_phi522885
  %arrayref531 = load double, double* %397, align 8
  %398 = fmul contract double %arrayref528, %arrayref531
  %399 = fadd reassoc contract double %value_phi521884, %398
  %400 = fmul contract double %arrayref531, %arrayref531
  %401 = fadd reassoc contract double %value_phi520883, %400
  %402 = add nuw nsw i64 %value_phi522885, 1
  %exitcond1043.not = icmp eq i64 %402, %arraylen517
  br i1 %exitcond1043.not, label %L647, label %L619

L647:                                             ; preds = %L619, %middle.block1618, %L606, %L577, %middle.block1641, %L563
  %value_phi312 = phi double [ 0.000000e+00, %L563 ], [ 0.000000e+00, %L606 ], [ %393, %middle.block1618 ], [ %357, %middle.block1641 ], [ %401, %L619 ], [ %368, %L577 ]
  %value_phi313 = phi double [ 0.000000e+00, %L563 ], [ 0.000000e+00, %L606 ], [ %394, %middle.block1618 ], [ %358, %middle.block1641 ], [ %399, %L619 ], [ %366, %L577 ]
  %value_phi314 = phi double [ 0.000000e+00, %L563 ], [ %arrayref287, %L606 ], [ %arrayref287, %middle.block1618 ], [ %359, %middle.block1641 ], [ %arrayref287, %L619 ], [ %364, %L577 ]
  %403 = fsub double %value_phi312, %value_phi312
  %404 = fcmp uno double %403, 0.000000e+00
  br i1 %404, label %L652, label %L654

L652:                                             ; preds = %L647
  %405 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %getfield272, {}** %405, align 8
  %406 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 2
  store {}* %getfield276, {}** %406, align 16
  call void @j__check_residual_755({}* nonnull %getfield276, i64 signext %value_phi267)
  br label %L654

L654:                                             ; preds = %L652, %L647
  %407 = fcmp une double %value_phi314, 0.000000e+00
  br i1 %407, label %L695, label %L656

L656:                                             ; preds = %L654
  %getfield316 = load atomic {}*, {}** %324 unordered, align 8
  %408 = bitcast {}* %getfield316 to {}**
  %arraysize_ptr317 = getelementptr inbounds {}*, {}** %408, i64 3
  %409 = bitcast {}** %arraysize_ptr317 to i64*
  %arraysize318 = load i64, i64* %409, align 8
  %.not649.not = icmp eq i64 %arraysize318, 0
  br i1 %.not649.not, label %L695, label %L669.preheader

L669.preheader:                                   ; preds = %L656
  %arraysize_ptr332 = getelementptr inbounds {}*, {}** %408, i64 4
  %410 = bitcast {}** %arraysize_ptr332 to i64*
  %arraysize333 = load i64, i64* %410, align 8
  %inbounds334 = icmp ult i64 %328, %arraysize333
  %411 = mul i64 %arraysize318, %328
  %412 = bitcast {}* %getfield316 to double**
  %arrayptr339651 = load double*, double** %412, align 8
  %inbounds334.fr = freeze i1 %inbounds334
  br i1 %inbounds334.fr, label %ib330.us, label %oob335

ib330.us:                                         ; preds = %L675.us, %L669.preheader
  %value_phi323.us = phi i64 [ %417, %L675.us ], [ 1, %L669.preheader ]
  %413 = add nsw i64 %value_phi323.us, -1
  %414 = add i64 %411, %413
  %415 = getelementptr inbounds double, double* %arrayptr339651, i64 %414
  %arrayref340.us = load double, double* %415, align 8
  %416 = fcmp une double %arrayref340.us, 0.000000e+00
  br i1 %416, label %L691.split.us, label %L675.us

L675.us:                                          ; preds = %ib330.us
  %417 = add nuw nsw i64 %value_phi323.us, 1
  %418 = icmp ult i64 %value_phi323.us, %arraysize318
  br i1 %418, label %ib330.us, label %L695

L691.split.us:                                    ; preds = %ib330.us
  store {}* inttoptr (i64 135794567260688 to {}*), {}** %6, align 8
  %419 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %419)
  unreachable

L695:                                             ; preds = %L675.us, %L656, %L654
  %420 = fsub double %value_phi314, %value_phi314
  %421 = fcmp uno double %420, 0.000000e+00
  br i1 %421, label %L1008, label %L700

L700:                                             ; preds = %L695
  %getfield348 = load atomic {}*, {}** %313 unordered, align 8
  %422 = bitcast {}* %getfield348 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr350 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %422, i64 0, i32 1
  %arraylen351 = load i64, i64* %arraylen_ptr350, align 8
  %.not653 = icmp ult i64 %328, %arraylen351
  br i1 %.not653, label %L714, label %L711

L711:                                             ; preds = %L700
  store i64 %value_phi267, i64* %314, align 8
  %423 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 2
  store {}* %getfield348, {}** %423, align 16
  call void @j_throw_boundserror_749({}* nonnull %getfield348, [1 x i64]* nocapture readonly %newstruct349) #3
  unreachable

L714:                                             ; preds = %L700
  %424 = bitcast {}* %getfield348 to i64**
  %arrayptr356654 = load i64*, i64** %424, align 8
  %425 = getelementptr inbounds i64, i64* %arrayptr356654, i64 %328
  %arrayref357 = load i64, i64* %425, align 8
  %.not655 = icmp eq i64 %arrayref357, 0
  br i1 %.not655, label %L724, label %L719

L719:                                             ; preds = %L714
  %426 = bitcast {}* %0 to double***
  %getfield5081851 = load atomic double**, double*** %426 unordered, align 8
  %427 = add i64 %arrayref357, -1
  %arrayptr510682 = load double*, double** %getfield5081851, align 8
  %428 = getelementptr inbounds double, double* %arrayptr510682, i64 %427
  %arrayref511 = load double, double* %428, align 8
  br label %L724

L724:                                             ; preds = %L719, %L714
  %value_phi358 = phi double [ %arrayref511, %L719 ], [ 0.000000e+00, %L714 ]
  br i1 %407, label %L728, label %L726

L726:                                             ; preds = %L724
  %429 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %getfield272, {}** %429, align 8
  %430 = call double @j__coordinate_minimizer_747({ double }* nocapture nonnull readonly %2, double %value_phi358, i64 signext %value_phi267)
  br label %L926

L728:                                             ; preds = %L724
  %getfield448 = load atomic {}*, {}** %311 unordered, align 8
  %431 = bitcast {}* %getfield448 to i8*
  %getfield_addr449 = getelementptr inbounds i8, i8* %431, i64 24
  %432 = bitcast i8* %getfield_addr449 to {}**
  %getfield450 = load atomic {}*, {}** %432 unordered, align 8
  %433 = bitcast {}* %getfield450 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr451 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %433, i64 0, i32 1
  %arraylen452 = load i64, i64* %arraylen_ptr451, align 8
  %434 = sitofp i64 %arraylen452 to double
  %435 = fmul double %434, 0x350000000000000
  %436 = fcmp ole double %435, %value_phi314
  %437 = fcmp ord double %403, 0.000000e+00
  %438 = fcmp ole double %435, %value_phi312
  %439 = and i1 %437, %438
  %440 = and i1 %436, %439
  br i1 %440, label %L747, label %L923

L747:                                             ; preds = %L728
  %aggregate_load_box453.sroa.0.0.copyload = load double, double* %aggregate_load_box453.sroa.0.0..sroa_idx, align 1
  %441 = fcmp uge double %value_phi314, 0.000000e+00
  br i1 %441, label %L753, label %L751

L751:                                             ; preds = %L747
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %value_phi314) #3
  unreachable

L753:                                             ; preds = %L747
  %442 = call double @llvm.sqrt.f64(double %value_phi314)
  %443 = fcmp ugt double %442, %aggregate_load_box453.sroa.0.0.copyload
  br i1 %443, label %L758, label %L926

L758:                                             ; preds = %L753
  %444 = fdiv double %value_phi313, %value_phi314
  %445 = fadd double %444, %value_phi358
  %446 = fmul double %value_phi313, %444
  %447 = fsub double %value_phi312, %446
  %448 = fmul double %value_phi312, 6.250000e-02
  %449 = fcmp uge double %447, %448
  br i1 %449, label %L813, label %L765

L765:                                             ; preds = %L758
  %.not672 = icmp eq i64 %arraylen452, 0
  br i1 %.not672, label %L802, label %L779.lr.ph

L779.lr.ph:                                       ; preds = %L765
  %450 = bitcast {}* %getfield448 to {}**
  %getfield458 = load atomic {}*, {}** %450 unordered, align 8
  %451 = bitcast {}* %getfield450 to double**
  %arrayptr468674 = load double*, double** %451, align 8
  %452 = bitcast {}* %getfield458 to {}**
  %arraysize_ptr470 = getelementptr inbounds {}*, {}** %452, i64 3
  %453 = bitcast {}** %arraysize_ptr470 to i64*
  %arraysize471 = load i64, i64* %453, align 8
  %454 = mul i64 %arraysize471, %328
  %455 = bitcast {}* %getfield458 to double**
  %arrayptr474675 = load double*, double** %455, align 8
  %min.iters.check1585 = icmp ult i64 %arraylen452, 16
  br i1 %min.iters.check1585, label %scalar.ph1584, label %vector.ph1586

vector.ph1586:                                    ; preds = %L779.lr.ph
  %n.vec1588 = and i64 %arraylen452, 9223372036854775792
  %broadcast.splatinsert1605 = insertelement <4 x double> poison, double %444, i64 0
  %broadcast.splat1606 = shufflevector <4 x double> %broadcast.splatinsert1605, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1591

vector.body1591:                                  ; preds = %vector.body1591, %vector.ph1586
  %index1592 = phi i64 [ 0, %vector.ph1586 ], [ %index.next1613, %vector.body1591 ]
  %vec.phi1593 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1586 ], [ %485, %vector.body1591 ]
  %vec.phi1594 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1586 ], [ %486, %vector.body1591 ]
  %vec.phi1595 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1586 ], [ %487, %vector.body1591 ]
  %vec.phi1596 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph1586 ], [ %488, %vector.body1591 ]
  %456 = getelementptr inbounds double, double* %arrayptr468674, i64 %index1592
  %457 = bitcast double* %456 to <4 x double>*
  %wide.load1597 = load <4 x double>, <4 x double>* %457, align 8
  %458 = getelementptr inbounds double, double* %456, i64 4
  %459 = bitcast double* %458 to <4 x double>*
  %wide.load1598 = load <4 x double>, <4 x double>* %459, align 8
  %460 = getelementptr inbounds double, double* %456, i64 8
  %461 = bitcast double* %460 to <4 x double>*
  %wide.load1599 = load <4 x double>, <4 x double>* %461, align 8
  %462 = getelementptr inbounds double, double* %456, i64 12
  %463 = bitcast double* %462 to <4 x double>*
  %wide.load1600 = load <4 x double>, <4 x double>* %463, align 8
  %464 = add i64 %454, %index1592
  %465 = getelementptr inbounds double, double* %arrayptr474675, i64 %464
  %466 = bitcast double* %465 to <4 x double>*
  %wide.load1601 = load <4 x double>, <4 x double>* %466, align 8
  %467 = getelementptr inbounds double, double* %465, i64 4
  %468 = bitcast double* %467 to <4 x double>*
  %wide.load1602 = load <4 x double>, <4 x double>* %468, align 8
  %469 = getelementptr inbounds double, double* %465, i64 8
  %470 = bitcast double* %469 to <4 x double>*
  %wide.load1603 = load <4 x double>, <4 x double>* %470, align 8
  %471 = getelementptr inbounds double, double* %465, i64 12
  %472 = bitcast double* %471 to <4 x double>*
  %wide.load1604 = load <4 x double>, <4 x double>* %472, align 8
  %473 = fmul <4 x double> %broadcast.splat1606, %wide.load1601
  %474 = fmul <4 x double> %broadcast.splat1606, %wide.load1602
  %475 = fmul <4 x double> %broadcast.splat1606, %wide.load1603
  %476 = fmul <4 x double> %broadcast.splat1606, %wide.load1604
  %477 = fsub <4 x double> %wide.load1597, %473
  %478 = fsub <4 x double> %wide.load1598, %474
  %479 = fsub <4 x double> %wide.load1599, %475
  %480 = fsub <4 x double> %wide.load1600, %476
  %481 = fmul contract <4 x double> %477, %477
  %482 = fmul contract <4 x double> %478, %478
  %483 = fmul contract <4 x double> %479, %479
  %484 = fmul contract <4 x double> %480, %480
  %485 = fadd reassoc contract <4 x double> %vec.phi1593, %481
  %486 = fadd reassoc contract <4 x double> %vec.phi1594, %482
  %487 = fadd reassoc contract <4 x double> %vec.phi1595, %483
  %488 = fadd reassoc contract <4 x double> %vec.phi1596, %484
  %index.next1613 = add nuw i64 %index1592, 16
  %489 = icmp eq i64 %index.next1613, %n.vec1588
  br i1 %489, label %middle.block1583, label %vector.body1591

middle.block1583:                                 ; preds = %vector.body1591
  %bin.rdx1614 = fadd reassoc contract <4 x double> %486, %485
  %bin.rdx1615 = fadd reassoc contract <4 x double> %487, %bin.rdx1614
  %bin.rdx1616 = fadd reassoc contract <4 x double> %488, %bin.rdx1615
  %490 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx1616)
  %cmp.n1590 = icmp eq i64 %arraylen452, %n.vec1588
  br i1 %cmp.n1590, label %L802, label %scalar.ph1584

scalar.ph1584:                                    ; preds = %middle.block1583, %L779.lr.ph
  %bc.resume.val1589 = phi i64 [ %n.vec1588, %middle.block1583 ], [ 0, %L779.lr.ph ]
  %bc.merge.rdx1617 = phi double [ %490, %middle.block1583 ], [ 0.000000e+00, %L779.lr.ph ]
  br label %L779

L779:                                             ; preds = %L779, %scalar.ph1584
  %value_phi466890 = phi i64 [ %bc.resume.val1589, %scalar.ph1584 ], [ %498, %L779 ]
  %value_phi465889 = phi double [ %bc.merge.rdx1617, %scalar.ph1584 ], [ %497, %L779 ]
  %491 = getelementptr inbounds double, double* %arrayptr468674, i64 %value_phi466890
  %arrayref469 = load double, double* %491, align 8
  %492 = add i64 %454, %value_phi466890
  %493 = getelementptr inbounds double, double* %arrayptr474675, i64 %492
  %arrayref475 = load double, double* %493, align 8
  %494 = fmul double %444, %arrayref475
  %495 = fsub double %arrayref469, %494
  %496 = fmul contract double %495, %495
  %497 = fadd reassoc contract double %value_phi465889, %496
  %498 = add nuw nsw i64 %value_phi466890, 1
  %exitcond1044.not = icmp eq i64 %498, %arraylen452
  br i1 %exitcond1044.not, label %L802, label %L779

L802:                                             ; preds = %L779, %middle.block1583, %L765
  %value_phi477 = phi double [ 0.000000e+00, %L765 ], [ %490, %middle.block1583 ], [ %497, %L779 ]
  %499 = fsub double %value_phi477, %value_phi477
  %500 = fcmp uno double %499, 0.000000e+00
  %501 = fcmp ugt double %435, %value_phi477
  %502 = or i1 %501, %500
  br i1 %502, label %L811, label %L813

L811:                                             ; preds = %L802
  %503 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %getfield272, {}** %503, align 8
  %504 = call double @j__sqrt_offrange_step_753({}* nonnull %1, double %value_phi358, i64 signext %value_phi267)
  br label %L926

L813:                                             ; preds = %L802, %L758
  %value_phi479 = phi double [ %447, %L758 ], [ %value_phi477, %L802 ]
  %505 = fcmp uge double %value_phi479, 0.000000e+00
  br i1 %505, label %L818, label %L816

L816:                                             ; preds = %L813
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %value_phi479) #3
  unreachable

L818:                                             ; preds = %L813
  %506 = call double @llvm.sqrt.f64(double %value_phi479)
  %507 = fsub double %442, %aggregate_load_box453.sroa.0.0.copyload
  %508 = fcmp uge double %507, 0.000000e+00
  br i1 %508, label %L825, label %L823

L823:                                             ; preds = %L818
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %507) #3
  unreachable

L825:                                             ; preds = %L818
  %509 = fadd double %442, %aggregate_load_box453.sroa.0.0.copyload
  %510 = fcmp uge double %509, 0.000000e+00
  br i1 %510, label %L832, label %L830

L830:                                             ; preds = %L825
  call void @j_throw_complex_domainerror_750({}* inttoptr (i64 135794596555280 to {}*), double %509) #3
  unreachable

L832:                                             ; preds = %L825
  %511 = call double @llvm.sqrt.f64(double %507)
  %512 = call double @llvm.sqrt.f64(double %509)
  %513 = fmul double %511, %512
  %514 = fmul double %442, %513
  %515 = fdiv double %506, %514
  %516 = fmul double %aggregate_load_box453.sroa.0.0.copyload, %515
  %517 = fcmp oge double %514, 0x10000000000000
  %518 = fcmp oge double %515, 0x10000000000000
  %519 = fcmp ole double %515, 0x7FEFFFFFFFFFFFFF
  %narrow676 = and i1 %518, %519
  %520 = and i1 %517, %narrow676
  %521 = fcmp oge double %516, 0x10000000000000
  %522 = fcmp ole double %516, 0x7FEFFFFFFFFFFFFF
  %narrow677 = and i1 %521, %522
  %523 = and i1 %520, %narrow677
  br i1 %523, label %L866, label %L921

L866:                                             ; preds = %L832
  %524 = fneg double %516
  %.inv679 = fcmp ogt double %445, %524
  %525 = select i1 %.inv679, double %445, double %524
  %.inv680 = fcmp olt double %525, %516
  %526 = select i1 %.inv680, double %525, double %516
  %527 = fsub double %445, %526
  %528 = fadd double %527, 0.000000e+00
  br label %L926

L921:                                             ; preds = %L832
  %529 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %getfield272, {}** %529, align 8
  %530 = call double @j__sqrt_band_step_752(double %445, double %442, double %aggregate_load_box453.sroa.0.0.copyload, double %506, i64 signext 0)
  br label %L926

L923:                                             ; preds = %L728
  %531 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 3
  store {}* %getfield272, {}** %531, align 8
  %532 = call double @j__sqrt_offrange_step_753({}* nonnull %1, double %value_phi358, i64 signext %value_phi267)
  br label %L926

L926:                                             ; preds = %L923, %L921, %L866, %L811, %L753, %L726
  %value_phi359 = phi double [ %430, %L726 ], [ %504, %L811 ], [ %530, %L921 ], [ %532, %L923 ], [ 0.000000e+00, %L753 ], [ %528, %L866 ]
  %getfield361 = load atomic {}*, {}** %327 unordered, align 8
  %533 = bitcast {}* %getfield361 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr362 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %533, i64 0, i32 1
  %arraylen363 = load i64, i64* %arraylen_ptr362, align 8
  %inbounds364 = icmp ult i64 %328, %arraylen363
  br i1 %inbounds364, label %idxend367, label %oob365

L934:                                             ; preds = %idxend367
  %getfield381 = load atomic {}*, {}** %313 unordered, align 8
  %534 = bitcast {}* %getfield381 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr383 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %534, i64 0, i32 1
  %arraylen384 = load i64, i64* %arraylen_ptr383, align 8
  %.not660 = icmp ult i64 %328, %arraylen384
  br i1 %.not660, label %L948, label %L945

L945:                                             ; preds = %L934
  store i64 %value_phi267, i64* %318, align 8
  %535 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 2
  store {}* %getfield381, {}** %535, align 16
  call void @j_throw_boundserror_749({}* nonnull %getfield381, [1 x i64]* nocapture readonly %newstruct382) #3
  unreachable

L948:                                             ; preds = %L934
  %536 = bitcast {}* %getfield381 to i64**
  %arrayptr389661 = load i64*, i64** %536, align 8
  %537 = getelementptr inbounds i64, i64* %arrayptr389661, i64 %328
  %arrayref390 = load i64, i64* %537, align 8
  %.not662 = icmp eq i64 %arrayref390, 0
  br i1 %.not662, label %L956, label %L953

L953:                                             ; preds = %L948
  %538 = bitcast {}* %0 to double***
  %getfield3921852 = load atomic double**, double*** %538 unordered, align 8
  %539 = add i64 %arrayref390, -1
  %arrayptr394663 = load double*, double** %getfield3921852, align 8
  %540 = getelementptr inbounds double, double* %arrayptr394663, i64 %539
  store double %value_phi359, double* %540, align 8
  br label %L973

L956:                                             ; preds = %L948
  %541 = fcmp oeq double %value_phi359, 0.000000e+00
  br i1 %541, label %L973, label %L959

L959:                                             ; preds = %L956
  %542 = load i64, i64* %320, align 8
  %543 = add i64 %542, 1
  store i64 %543, i64* %320, align 8
  %getfield417 = load atomic {}*, {}** %315 unordered, align 8
  %544 = bitcast {}* %getfield417 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr418 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %544, i64 0, i32 1
  %arraylen419 = load i64, i64* %arraylen_ptr418, align 8
  %inbounds420 = icmp ult i64 %542, %arraylen419
  br i1 %inbounds420, label %idxend423, label %oob421

L973:                                             ; preds = %idxend443, %L956, %L953
  %getfield396 = load atomic {}*, {}** %326 unordered, align 8
  %545 = bitcast {}* %getfield396 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr399 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %545, i64 0, i32 1
  %arraylen400 = load i64, i64* %arraylen_ptr399, align 8
  %.not664 = icmp eq i64 %arraylen400, 0
  br i1 %.not664, label %L1010, label %L986.lr.ph

L986.lr.ph:                                       ; preds = %L973
  %getfield398 = load atomic {}*, {}** %324 unordered, align 8
  %546 = bitcast {}* %getfield396 to double**
  %arrayptr405666 = load double*, double** %546, align 8
  %547 = bitcast {}* %getfield398 to {}**
  %arraysize_ptr407 = getelementptr inbounds {}*, {}** %547, i64 3
  %548 = bitcast {}** %arraysize_ptr407 to i64*
  %arraysize408 = load i64, i64* %548, align 8
  %549 = mul i64 %arraysize408, %328
  %550 = bitcast {}* %getfield398 to double**
  %arrayptr411667 = load double*, double** %550, align 8
  %min.iters.check1558 = icmp ult i64 %arraylen400, 16
  br i1 %min.iters.check1558, label %scalar.ph1557, label %vector.memcheck1545

vector.memcheck1545:                              ; preds = %L986.lr.ph
  %arrayptr4116671549 = bitcast double* %arrayptr411667 to i8*
  %arrayptr4056661546 = bitcast double* %arrayptr405666 to i8*
  %scevgep1547 = getelementptr double, double* %arrayptr405666, i64 %arraylen400
  %scevgep15471548 = bitcast double* %scevgep1547 to i8*
  %551 = mul i64 %arraysize408, %323
  %uglygep = getelementptr i8, i8* %arrayptr4116671549, i64 %551
  %scevgep1550 = getelementptr double, double* %arrayptr411667, i64 %arraylen400
  %scevgep15501551 = bitcast double* %scevgep1550 to i8*
  %uglygep1552 = getelementptr i8, i8* %scevgep15501551, i64 %551
  %bound01553 = icmp ugt i8* %uglygep1552, %arrayptr4056661546
  %bound11554 = icmp ult i8* %uglygep, %scevgep15471548
  %found.conflict1555 = and i1 %bound01553, %bound11554
  br i1 %found.conflict1555, label %scalar.ph1557, label %vector.ph1559

vector.ph1559:                                    ; preds = %vector.memcheck1545
  %n.vec1561 = and i64 %arraylen400, 9223372036854775792
  %broadcast.splatinsert1574 = insertelement <4 x double> poison, double %617, i64 0
  %broadcast.splat1575 = shufflevector <4 x double> %broadcast.splatinsert1574, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body1564

vector.body1564:                                  ; preds = %vector.body1564, %vector.ph1559
  %index1565 = phi i64 [ 0, %vector.ph1559 ], [ %index.next1582, %vector.body1564 ]
  %552 = getelementptr inbounds double, double* %arrayptr405666, i64 %index1565
  %553 = bitcast double* %552 to <4 x double>*
  %wide.load1566 = load <4 x double>, <4 x double>* %553, align 8
  %554 = getelementptr inbounds double, double* %552, i64 4
  %555 = bitcast double* %554 to <4 x double>*
  %wide.load1567 = load <4 x double>, <4 x double>* %555, align 8
  %556 = getelementptr inbounds double, double* %552, i64 8
  %557 = bitcast double* %556 to <4 x double>*
  %wide.load1568 = load <4 x double>, <4 x double>* %557, align 8
  %558 = getelementptr inbounds double, double* %552, i64 12
  %559 = bitcast double* %558 to <4 x double>*
  %wide.load1569 = load <4 x double>, <4 x double>* %559, align 8
  %560 = add i64 %549, %index1565
  %561 = getelementptr inbounds double, double* %arrayptr411667, i64 %560
  %562 = bitcast double* %561 to <4 x double>*
  %wide.load1570 = load <4 x double>, <4 x double>* %562, align 8
  %563 = getelementptr inbounds double, double* %561, i64 4
  %564 = bitcast double* %563 to <4 x double>*
  %wide.load1571 = load <4 x double>, <4 x double>* %564, align 8
  %565 = getelementptr inbounds double, double* %561, i64 8
  %566 = bitcast double* %565 to <4 x double>*
  %wide.load1572 = load <4 x double>, <4 x double>* %566, align 8
  %567 = getelementptr inbounds double, double* %561, i64 12
  %568 = bitcast double* %567 to <4 x double>*
  %wide.load1573 = load <4 x double>, <4 x double>* %568, align 8
  %569 = fmul <4 x double> %broadcast.splat1575, %wide.load1570
  %570 = fmul <4 x double> %broadcast.splat1575, %wide.load1571
  %571 = fmul <4 x double> %broadcast.splat1575, %wide.load1572
  %572 = fmul <4 x double> %broadcast.splat1575, %wide.load1573
  %573 = fsub <4 x double> %wide.load1566, %569
  %574 = fsub <4 x double> %wide.load1567, %570
  %575 = fsub <4 x double> %wide.load1568, %571
  %576 = fsub <4 x double> %wide.load1569, %572
  store <4 x double> %573, <4 x double>* %553, align 8
  store <4 x double> %574, <4 x double>* %555, align 8
  store <4 x double> %575, <4 x double>* %557, align 8
  store <4 x double> %576, <4 x double>* %559, align 8
  %index.next1582 = add nuw i64 %index1565, 16
  %577 = icmp eq i64 %index.next1582, %n.vec1561
  br i1 %577, label %middle.block1556, label %vector.body1564

middle.block1556:                                 ; preds = %vector.body1564
  %cmp.n1563 = icmp eq i64 %arraylen400, %n.vec1561
  br i1 %cmp.n1563, label %L1010, label %scalar.ph1557

scalar.ph1557:                                    ; preds = %middle.block1556, %vector.memcheck1545, %L986.lr.ph
  %bc.resume.val1562 = phi i64 [ %n.vec1561, %middle.block1556 ], [ 0, %L986.lr.ph ], [ 0, %vector.memcheck1545 ]
  br label %L986

L986:                                             ; preds = %L986, %scalar.ph1557
  %value_phi403893 = phi i64 [ %bc.resume.val1562, %scalar.ph1557 ], [ %583, %L986 ]
  %578 = getelementptr inbounds double, double* %arrayptr405666, i64 %value_phi403893
  %arrayref406 = load double, double* %578, align 8
  %579 = add i64 %549, %value_phi403893
  %580 = getelementptr inbounds double, double* %arrayptr411667, i64 %579
  %arrayref412 = load double, double* %580, align 8
  %581 = fmul double %617, %arrayref412
  %582 = fsub double %arrayref406, %581
  store double %582, double* %578, align 8
  %583 = add nuw nsw i64 %value_phi403893, 1
  %exitcond1045.not = icmp eq i64 %583, %arraylen400
  br i1 %exitcond1045.not, label %L1010, label %L986

L1008:                                            ; preds = %L695
  call void @j__refuse_curvature_754(i64 signext %value_phi267) #3
  unreachable

L1010:                                            ; preds = %idxend367, %L986, %middle.block1556, %L973
  %value_phi267997 = phi i64 [ %value_phi267, %L973 ], [ %value_phi267998, %idxend367 ], [ %value_phi267, %middle.block1556 ], [ %value_phi267, %L986 ]
  %584 = call double @llvm.fabs.f64(double %617)
  %585 = fcmp oeq double %617, 0.000000e+00
  %or.cond1292 = select i1 %.not657, i1 true, i1 %585
  br i1 %or.cond1292, label %L1021, label %L1016

L1016:                                            ; preds = %L1010
  %getfield372 = load atomic {}*, {}** %311 unordered, align 8
  %586 = getelementptr inbounds [5 x {}*], [5 x {}*]* %gcframe1848, i64 0, i64 2
  store {}* %getfield372, {}** %586, align 16
  %587 = call double @j_coordinate_scale_748({}* nonnull %getfield372, {}* nonnull %0, i64 signext %value_phi267)
  %588 = fmul double %584, %587
  br label %L1021

L1021:                                            ; preds = %L1016, %L1010
  %value_phi373 = phi double [ %588, %L1016 ], [ %584, %L1010 ]
  %589 = fsub double %value_phi373, %value_phi373
  %590 = fcmp uno double %589, 0.000000e+00
  br i1 %590, label %L1027, label %L1030

L1027:                                            ; preds = %L1021
  store {}* inttoptr (i64 135794568219280 to {}*), {}** %6, align 8
  %591 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 135794436290208 to {}*), {}** nonnull %6, i32 1)
  call void @ijl_throw({}* %591)
  unreachable

L1030:                                            ; preds = %L1021
  %.inv658 = fcmp olt double %value_phi269, %value_phi373
  %592 = select i1 %.inv658, double %value_phi373, double %value_phi269
  %.not659.not = icmp eq i64 %value_phi267, %309
  %593 = add nuw i64 %value_phi267, 1
  %indvar.next = add i64 %indvar, 1
  br i1 %.not659.not, label %L1045.loopexit, label %L543

L1045.loopexit:                                   ; preds = %L1030
  store i64 %309, i64* %314, align 8
  store i64 %value_phi267997, i64* %318, align 8
  br label %L1045

L1045.loopexit691:                                ; preds = %L510
  store i64 %arrayref, i64* %26, align 8
  store i64 %arrayref936, i64* %30, align 8
  br label %L1045

L1045:                                            ; preds = %L1045.loopexit691, %L1045.loopexit, %L527, %L4
  %value_phi103 = phi double [ 0.000000e+00, %L4 ], [ 0.000000e+00, %L527 ], [ %592, %L1045.loopexit ], [ %307, %L1045.loopexit691 ]
  %594 = load {}*, {}** %10, align 8
  %595 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %594, {}** %595, align 8
  ret double %value_phi103

oob:                                              ; preds = %L22
  %errorbox = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L22
  %596 = bitcast {}* %getfield16 to double**
  %arrayptr18601 = load double*, double** %596, align 8
  %597 = getelementptr inbounds double, double* %arrayptr18601, i64 %41
  %arrayref19 = load double, double* %597, align 8
  %598 = fcmp ord double %arrayref19, 0.000000e+00
  %599 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr240 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %599, i64 0, i32 1
  %arraylen241 = load i64, i64* %arraylen_ptr240, align 8
  %.not639 = icmp eq i64 %arraylen241, 0
  br i1 %598, label %L86, label %L43

oob60:                                            ; preds = %L149.preheader
  %errorbox61607 = alloca [2 x i64], align 8
  %errorbox61607.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 0
  store i64 1, i64* %errorbox61607.sub, align 8
  %600 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox61607, i64 0, i64 1
  store i64 %arrayref, i64* %600, align 8
  call void @ijl_bounds_error_ints({}* %getfield42, i64* nonnull %errorbox61607.sub, i64 2)
  unreachable

oob89:                                            ; preds = %L406
  %errorbox90 = alloca i64, align 8
  store i64 %arrayref, i64* %errorbox90, align 8
  call void @ijl_bounds_error_ints({}* %getfield85, i64* nonnull %errorbox90, i64 1)
  unreachable

idxend91:                                         ; preds = %L406
  %601 = bitcast {}* %getfield85 to double**
  %arrayptr93613 = load double*, double** %601, align 8
  %602 = getelementptr inbounds double, double* %arrayptr93613, i64 %41
  store double %value_phi40, double* %602, align 8
  %603 = fsub double %value_phi83, %value_phi82
  %604 = fcmp une double %603, 0.000000e+00
  br i1 %604, label %L414, label %L490

oob147:                                           ; preds = %L439
  %errorbox148 = alloca i64, align 8
  store i64 %258, i64* %errorbox148, align 8
  call void @ijl_bounds_error_ints({}* %getfield143, i64* nonnull %errorbox148, i64 1)
  unreachable

idxend149:                                        ; preds = %L439
  %605 = bitcast {}* %getfield143 to double**
  %arrayptr151626 = load double*, double** %605, align 8
  %606 = getelementptr inbounds double, double* %arrayptr151626, i64 %257
  store double %value_phi83, double* %606, align 8
  %getfield153 = load atomic {}*, {}** %33 unordered, align 8
  %607 = bitcast {}* %getfield153 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr154 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %607, i64 0, i32 1
  %arraylen155 = load i64, i64* %arraylen_ptr154, align 8
  %inbounds156 = icmp ult i64 %257, %arraylen155
  br i1 %inbounds156, label %idxend169, label %oob157

oob157:                                           ; preds = %idxend149
  %errorbox158 = alloca i64, align 8
  store i64 %258, i64* %errorbox158, align 8
  call void @ijl_bounds_error_ints({}* %getfield153, i64* nonnull %errorbox158, i64 1)
  unreachable

idxend169:                                        ; preds = %idxend149
  %608 = bitcast {}* %getfield153 to i64**
  %arrayptr161627 = load i64*, i64** %608, align 8
  %609 = getelementptr inbounds i64, i64* %arrayptr161627, i64 %257
  store i64 %arrayref, i64* %609, align 8
  store i64 %258, i64* %252, align 8
  br label %L453

oob282:                                           ; preds = %L543
  %errorbox283 = alloca i64, align 8
  store i64 %value_phi267, i64* %errorbox283, align 8
  call void @ijl_bounds_error_ints({}* %getfield278, i64* nonnull %errorbox283, i64 1)
  unreachable

idxend284:                                        ; preds = %L543
  %610 = bitcast {}* %getfield278 to double**
  %arrayptr286644 = load double*, double** %610, align 8
  %611 = getelementptr inbounds double, double* %arrayptr286644, i64 %328
  %arrayref287 = load double, double* %611, align 8
  %612 = fcmp ord double %arrayref287, 0.000000e+00
  %613 = bitcast {}* %getfield276 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr516 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %613, i64 0, i32 1
  %arraylen517 = load i64, i64* %arraylen_ptr516, align 8
  %.not683 = icmp eq i64 %arraylen517, 0
  br i1 %612, label %L606, label %L563

oob335:                                           ; preds = %L669.preheader
  %errorbox336650 = alloca [2 x i64], align 8
  %errorbox336650.sub = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox336650, i64 0, i64 0
  store i64 1, i64* %errorbox336650.sub, align 8
  %614 = getelementptr inbounds [2 x i64], [2 x i64]* %errorbox336650, i64 0, i64 1
  store i64 %value_phi267, i64* %614, align 8
  call void @ijl_bounds_error_ints({}* %getfield316, i64* nonnull %errorbox336650.sub, i64 2)
  unreachable

oob365:                                           ; preds = %L926
  %errorbox366 = alloca i64, align 8
  store i64 %value_phi267, i64* %errorbox366, align 8
  call void @ijl_bounds_error_ints({}* %getfield361, i64* nonnull %errorbox366, i64 1)
  unreachable

idxend367:                                        ; preds = %L926
  %615 = bitcast {}* %getfield361 to double**
  %arrayptr369656 = load double*, double** %615, align 8
  %616 = getelementptr inbounds double, double* %arrayptr369656, i64 %328
  store double %value_phi314, double* %616, align 8
  %617 = fsub double %value_phi359, %value_phi358
  %618 = fcmp une double %617, 0.000000e+00
  br i1 %618, label %L934, label %L1010

oob421:                                           ; preds = %L959
  %errorbox422 = alloca i64, align 8
  store i64 %543, i64* %errorbox422, align 8
  call void @ijl_bounds_error_ints({}* %getfield417, i64* nonnull %errorbox422, i64 1)
  unreachable

idxend423:                                        ; preds = %L959
  %619 = bitcast {}* %getfield417 to double**
  %arrayptr425669 = load double*, double** %619, align 8
  %620 = getelementptr inbounds double, double* %arrayptr425669, i64 %542
  store double %value_phi359, double* %620, align 8
  %getfield427 = load atomic {}*, {}** %321 unordered, align 8
  %621 = bitcast {}* %getfield427 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr428 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %621, i64 0, i32 1
  %arraylen429 = load i64, i64* %arraylen_ptr428, align 8
  %inbounds430 = icmp ult i64 %542, %arraylen429
  br i1 %inbounds430, label %idxend443, label %oob431

oob431:                                           ; preds = %idxend423
  %errorbox432 = alloca i64, align 8
  store i64 %543, i64* %errorbox432, align 8
  call void @ijl_bounds_error_ints({}* %getfield427, i64* nonnull %errorbox432, i64 1)
  unreachable

idxend443:                                        ; preds = %idxend423
  %622 = bitcast {}* %getfield427 to i64**
  %arrayptr435670 = load i64*, i64** %622, align 8
  %623 = getelementptr inbounds i64, i64* %arrayptr435670, i64 %542
  store i64 %value_phi267, i64* %623, align 8
  store i64 %543, i64* %537, align 8
  br label %L973
}
