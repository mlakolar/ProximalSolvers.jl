define double @julia_norm_diff_710({}* noundef nonnull align 16 dereferenceable(40) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, double %2) #0 {
top:
  %3 = alloca {}*, align 8
  %gcframe58 = alloca [3 x {}*], align 16
  %gcframe58.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe58, i64 0, i64 0
  %4 = bitcast [3 x {}*]* %gcframe58 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %4, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #11
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %5 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %5, align 8
  %6 = bitcast [3 x {}*]* %gcframe58 to i64*
  store i64 4, i64* %6, align 16
  %7 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe58, i64 0, i64 1
  %8 = bitcast {}** %7 to {}***
  %9 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %9, {}*** %8, align 8
  %10 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe58.sub, {}*** %10, align 8
  %11 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %11, i64 0, i32 1
  %arraylen = load i64, i64* %arraylen_ptr, align 8
  %12 = bitcast {}* %1 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr1 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %12, i64 0, i32 1
  %arraylen2 = load i64, i64* %arraylen_ptr1, align 8
  %.not.not = icmp eq i64 %arraylen, %arraylen2
  br i1 %.not.not, label %L13, label %L84

L13:                                              ; preds = %top
  %13 = fcmp une double %2, 2.000000e+00
  br i1 %13, label %L20, label %L18

common.ret:                                       ; preds = %L53, %L44, %L18
  %common.ret.op = phi double [ %16, %L18 ], [ 0.000000e+00, %L44 ], [ %29, %L53 ]
  %14 = load {}*, {}** %7, align 8
  %15 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %14, {}** %15, align 8
  ret double %common.ret.op

L18:                                              ; preds = %L13
  %16 = call double @j__norm_diff2_712({}* nonnull %0, {}* nonnull %1)
  br label %common.ret

L20:                                              ; preds = %L13
  %17 = fcmp une double %2, 0x7FF0000000000000
  br i1 %17, label %L81, label %L44

L44:                                              ; preds = %L20
  %.not50.not = icmp eq i64 %arraylen, 0
  br i1 %.not50.not, label %common.ret, label %L53.preheader

L53.preheader:                                    ; preds = %L44
  %18 = bitcast {}* %0 to double**
  %arrayptr51 = load double*, double** %18, align 8
  %19 = bitcast {}* %1 to double**
  %arrayptr1552 = load double*, double** %19, align 8
  br label %L53

L53:                                              ; preds = %L53, %L53.preheader
  %value_phi11 = phi i64 [ %30, %L53 ], [ 1, %L53.preheader ]
  %value_phi13 = phi double [ %29, %L53 ], [ 0.000000e+00, %L53.preheader ]
  %20 = add nsw i64 %value_phi11, -1
  %21 = getelementptr inbounds double, double* %arrayptr51, i64 %20
  %arrayref = load double, double* %21, align 8
  %22 = getelementptr inbounds double, double* %arrayptr1552, i64 %20
  %arrayref16 = load double, double* %22, align 8
  %23 = fsub double %arrayref, %arrayref16
  %24 = call double @llvm.fabs.f64(double %23)
  %25 = fsub double %value_phi13, %24
  %bitcast_coercion = bitcast double %25 to i64
  %26 = icmp slt i64 %bitcast_coercion, 0
  %27 = select i1 %26, double %24, double %value_phi13
  %28 = fcmp ord double %value_phi13, %23
  %29 = select i1 %28, double %27, double %25
  %.not53.not = icmp eq i64 %value_phi11, %arraylen
  %30 = add nuw nsw i64 %value_phi11, 1
  br i1 %.not53.not, label %common.ret, label %L53

L81:                                              ; preds = %L20
  store {}* inttoptr (i64 124166376122368 to {}*), {}** %3, align 8
  %31 = call nonnull {}* @ijl_apply_generic({}* inttoptr (i64 124167938848416 to {}*), {}** nonnull %3, i32 1)
  call void @ijl_throw({}* %31)
  unreachable

L84:                                              ; preds = %top
  %32 = call [1 x {}*] @j_DimensionMismatch_713({}* inttoptr (i64 124168008058432 to {}*))
  %33 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe58, i64 0, i64 2
  %34 = extractvalue [1 x {}*] %32, 0
  store {}* %34, {}** %33, align 16
  %ptls_field59 = getelementptr inbounds {}**, {}*** %tls_pgcstack, i64 2
  %35 = bitcast {}*** %ptls_field59 to i8**
  %ptls_load6061 = load i8*, i8** %35, align 8
  %box37 = call noalias nonnull dereferenceable(16) {}* @ijl_gc_pool_alloc(i8* %ptls_load6061, i32 752, i32 16) #9
  %36 = bitcast {}* %box37 to i64*
  %37 = getelementptr inbounds i64, i64* %36, i64 -1
  store atomic i64 124167910077920, i64* %37 unordered, align 8
  %38 = bitcast {}* %box37 to {}**
  store {}* %34, {}** %38, align 8
  call void @ijl_throw({}* %box37)
  unreachable
}
