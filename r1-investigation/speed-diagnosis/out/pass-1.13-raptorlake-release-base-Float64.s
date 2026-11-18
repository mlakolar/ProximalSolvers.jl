	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia_pass_1509
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
.LCPI0_5:
	.quad	0x0010000000000000              # double 2.2250738585072014E-308
.LCPI0_6:
	.quad	0x7fefffffffffffff              # double 1.7976931348623157E+308
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5, 0x0
.LCPI0_1:
	.quad	0x0000000000000000              # double 0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
.LCPI0_4:
	.zero	8
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_7:
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.section	.ltext,"axl",@progbits
	.globl	julia_pass_1509
	.p2align	4
	.type	julia_pass_1509,@function
julia_pass_1509:                        # @julia_pass_1509
; Function Signature: pass(typeof(M_base.ProximalSolvers._column_dot_rsqr), typeof(M_base.ProximalSolvers._sqrt_minimizer), M_base.ProximalSolvers.SqrtLSModel{Float64, M_base.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
# %bb.0:                                # %top
	#DEBUG_VALUE: pass:m <- [$rdi+0]
	#DEBUG_VALUE: pass:xv <- [$rsi+0]
	#DEBUG_VALUE: pass:reps <- $rdx
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 160
	vxorpd	xmm0, xmm0, xmm0
	vmovapd	xmmword ptr [rsp + 32], xmm0
	mov	qword ptr [rsp + 48], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rsp + 32], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rsp + 40], rax
	lea	rax, [rsp + 32]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorpd	xmm15, xmm15, xmm15
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rsp + 64], rax       # 8-byte Spill
	jle	.LBB0_73
# %bb.1:                                # %L17.preheader
	mov	rbx, rsi
	mov	r11, qword ptr [rsi + 16]
	test	r11, r11
	jle	.LBB0_73
# %bb.2:                                # %L17.preheader4
	mov	r14, rdi
	mov	qword ptr [rsp + 56], rcx       # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorpd	xmm13, xmm13, xmm13
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rcx]
	vmovapd	ymmword ptr [rsp + 96], ymm0    # 32-byte Spill
	.p2align	4
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_13 Depth 3
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_55 Depth 3
	mov	qword ptr [rsp + 72], rax       # 8-byte Spill
	test	r11, r11
	jle	.LBB0_71
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15d, 1
	xor	r13d, r13d
	mov	qword ptr [rsp + 24], r11       # 8-byte Spill
	jmp	.LBB0_6
	.p2align	4
.LBB0_69:                               # %L578
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 48], r12
	mov	rdi, r14
	vmovapd	xmm0, xmm3
	mov	rsi, r15
	vmovsd	qword ptr [rsp + 16], xmm15     # 8-byte Spill
	movabs	rax, offset j__sqrt_offrange_step_1520
	vzeroupper
	call	rax
	mov	r11, qword ptr [rsp + 24]       # 8-byte Reload
	vxorpd	xmm13, xmm13, xmm13
	vmovsd	xmm15, qword ptr [rsp + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vmovapd	xmm4, xmm0
.LBB0_70:                               # %L580
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm15, xmm15, xmm4
	lea	rax, [r15 + 1]
	add	r13, 8
	cmp	r15, r11
	mov	r15, rax
	je	.LBB0_71
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_13 Depth 3
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_55 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	rax, [r15 - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_74
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r12]
	mov	rsi, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovsd	xmm0, qword ptr [rcx + 8*r15 - 8] # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm0
	mov	rcx, qword ptr [rsi + 16]
	jp	.LBB0_8
# %bb.17:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_18
# %bb.19:                               # %iter.check447
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_21
# %bb.20:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm6, xmm6, xmm6
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_30
	.p2align	4
.LBB0_18:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_32
	.p2align	4
.LBB0_21:                               # %vector.main.loop.iter.check449
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 16
	jae	.LBB0_23
# %bb.22:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm6, xmm6, xmm6
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_27
.LBB0_23:                               # %vector.ph450
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	r9, 9223372036854775792
	and	rdi, r9
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastsd	ymm1, qword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm3, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm6, ymm1
	vmovapd	ymm8, ymm1
	vmovapd	ymm2, ymm3
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm1
	vmovapd	ymm7, ymm1
	.p2align	4
.LBB0_24:                               # %vector.body453
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm9, ymmword ptr [rsi + 8*r10]
	vmovupd	ymm10, ymmword ptr [rsi + 8*r10 + 32]
	vmovupd	ymm11, ymmword ptr [rsi + 8*r10 + 64]
	vmovupd	ymm12, ymmword ptr [rsi + 8*r10 + 96]
	vfmadd231pd	ymm3, ymm9, ymmword ptr [r9 + 8*r10 - 96] # ymm3 = (ymm9 * mem) + ymm3
	vfmadd231pd	ymm1, ymm10, ymmword ptr [r9 + 8*r10 - 64] # ymm1 = (ymm10 * mem) + ymm1
	vfmadd231pd	ymm6, ymm11, ymmword ptr [r9 + 8*r10 - 32] # ymm6 = (ymm11 * mem) + ymm6
	vfmadd231pd	ymm8, ymm12, ymmword ptr [r9 + 8*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vfmadd231pd	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231pd	ymm5, ymm11, ymm11      # ymm5 = (ymm11 * ymm11) + ymm5
	vfmadd231pd	ymm7, ymm12, ymm12      # ymm7 = (ymm12 * ymm12) + ymm7
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_24
# %bb.25:                               # %middle.block444
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm1, ymm1, ymm3
	vaddpd	ymm1, ymm6, ymm1
	vaddpd	ymm1, ymm8, ymm1
	vextractf128	xmm3, ymm1, 1
	vaddpd	xmm1, xmm1, xmm3
	vshufpd	xmm3, xmm1, xmm1, 1             # xmm3 = xmm1[1,0]
	vaddsd	xmm6, xmm1, xmm3
	vaddpd	ymm1, ymm4, ymm2
	vaddpd	ymm1, ymm5, ymm1
	vaddpd	ymm1, ymm7, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddsd	xmm7, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_32
# %bb.26:                               # %vec.epilog.iter.check485
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	je	.LBB0_30
.LBB0_27:                               # %vec.epilog.ph484
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	movabs	rdi, 9223372036854775792
	add	rdi, 12
	and	rdi, rcx
	vmovapd	ymm1, ymmword ptr [rsp + 96]    # 32-byte Reload
	vblendpd	ymm2, ymm1, ymm6, 1             # ymm2 = ymm6[0],ymm1[1,2,3]
	vblendpd	ymm1, ymm1, ymm7, 1             # ymm1 = ymm7[0],ymm1[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
	.p2align	4
.LBB0_28:                               # %vec.epilog.vector.body490
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm3, ymmword ptr [rsi + 8*r9]
	vfmadd231pd	ymm2, ymm3, ymmword ptr [r10 + 8*r9] # ymm2 = (ymm3 * mem) + ymm2
	vfmadd231pd	ymm1, ymm3, ymm3        # ymm1 = (ymm3 * ymm3) + ymm1
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_28
# %bb.29:                               # %vec.epilog.middle.block482
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddsd	xmm6, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddsd	xmm7, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_32
.LBB0_30:                               # %L190.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4
.LBB0_31:                               # %L190
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [rsi + 8*rdi]   # xmm1 = mem[0],zero
	vfmadd231sd	xmm6, xmm1, qword ptr [rdx + 8*rdi] # xmm6 = (xmm1 * mem) + xmm6
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm7, xmm1, xmm1        # xmm7 = (xmm1 * xmm1) + xmm7
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_31
.LBB0_32:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [rbx + 16]
	jae	.LBB0_75
# %bb.33:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rbx]
	vmovsd	xmm3, qword ptr [rax + 8*r15 - 8] # xmm3 = mem[0],zero
	vsubsd	xmm1, xmm0, xmm0
	vucomisd	xmm1, xmm1
	jp	.LBB0_69
# %bb.34:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [r14]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 16]
	vxorps	xmm14, xmm14, xmm14
	vcvtsi2sd	xmm1, xmm14, rax
	movabs	rsi, offset .LCPI0_2
	vmulsd	xmm5, xmm1, qword ptr [rsi]
	vucomisd	xmm0, xmm5
	jb	.LBB0_69
# %bb.35:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm1, xmm7, xmm7
	vucomisd	xmm1, xmm1
	jp	.LBB0_69
# %bb.36:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm7, xmm5
	jb	.LBB0_69
# %bb.37:                               # %L337
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm13, xmm0
	ja	.LBB0_76
# %bb.38:                               # %L343
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovsd	xmm2, qword ptr [r14 + 8]       # xmm2 = mem[0],zero
	vsqrtsd	xmm1, xmm0, xmm0
	vxorpd	xmm4, xmm4, xmm4
	vucomisd	xmm2, xmm1
	jae	.LBB0_70
# %bb.39:                               # %L348
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm4, xmm6, xmm0
	vmulsd	xmm0, xmm6, xmm4
	vsubsd	xmm0, xmm7, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm6, xmm7, qword ptr [rsi]
	vucomisd	xmm6, xmm0
	jbe	.LBB0_59
# %bb.40:                               # %L355
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	jle	.LBB0_41
# %bb.42:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	rdx, qword ptr [rsi]
	mov	rsi, qword ptr [rsi + 16]
	cmp	rax, 4
	jae	.LBB0_44
# %bb.43:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	jmp	.LBB0_54
.LBB0_41:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_56
.LBB0_44:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, 15
	ja	.LBB0_46
# %bb.45:                               # %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
                                        #   in Loop: Header=BB0_6 Depth=2
	vbroadcastsd	ymm6, xmm4
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	jmp	.LBB0_51
.LBB0_46:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rax
	movabs	r8, 9223372036854775792
	and	rdi, r8
	vbroadcastsd	ymm6, xmm4
	mov	r8, rsi
	imul	r8, r13
	add	r8, rdx
	add	r8, 96
	movabs	r9, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [r9]
	movabs	r9, offset .LCPI0_1
	vmovapd	ymm7, ymmword ptr [r9]
	xor	r9d, r9d
	vmovapd	ymm8, ymm0
	vmovapd	ymm9, ymm0
	.p2align	4
.LBB0_47:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm10, ymmword ptr [rcx + 8*r9]
	vmovupd	ymm11, ymmword ptr [rcx + 8*r9 + 32]
	vmovupd	ymm12, ymmword ptr [rcx + 8*r9 + 64]
	vmovupd	ymm13, ymmword ptr [rcx + 8*r9 + 96]
	vmulpd	ymm14, ymm6, ymmword ptr [r8 + 8*r9 - 96]
	vsubpd	ymm10, ymm10, ymm14
	vmulpd	ymm14, ymm6, ymmword ptr [r8 + 8*r9 - 64]
	vsubpd	ymm11, ymm11, ymm14
	vmulpd	ymm14, ymm6, ymmword ptr [r8 + 8*r9 - 32]
	vsubpd	ymm12, ymm12, ymm14
	vmulpd	ymm14, ymm6, ymmword ptr [r8 + 8*r9]
	vsubpd	ymm13, ymm13, ymm14
	vfmadd231pd	ymm7, ymm10, ymm10      # ymm7 = (ymm10 * ymm10) + ymm7
	vfmadd231pd	ymm0, ymm11, ymm11      # ymm0 = (ymm11 * ymm11) + ymm0
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	vfmadd231pd	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	r9, 16
	cmp	rdi, r9
	jne	.LBB0_47
# %bb.48:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm0, ymm7
	vaddpd	ymm0, ymm8, ymm0
	vaddpd	ymm0, ymm9, ymm0
	vextractf128	xmm7, ymm0, 1
	vaddpd	xmm0, xmm0, xmm7
	vshufpd	xmm7, xmm0, xmm0, 1             # xmm7 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm7
	cmp	rax, rdi
	jne	.LBB0_50
# %bb.49:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm13, xmm13, xmm13
	jmp	.LBB0_56
.LBB0_50:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	al, 12
	vxorpd	xmm13, xmm13, xmm13
	je	.LBB0_54
.LBB0_51:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, rdi
	movabs	rdi, 9223372036854775792
	add	rdi, 12
	and	rdi, rax
	movabs	r9, offset .LCPI0_4
	vblendpd	ymm0, ymm0, ymmword ptr [r9], 14 # ymm0 = ymm0[0],mem[1,2,3]
	mov	r9, rsi
	imul	r9, r13
	add	r9, rdx
	.p2align	4
.LBB0_52:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm7, ymmword ptr [rcx + 8*r8]
	vmulpd	ymm8, ymm6, ymmword ptr [r9 + 8*r8]
	vsubpd	ymm7, ymm7, ymm8
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	add	r8, 4
	cmp	rdi, r8
	jne	.LBB0_52
# %bb.53:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm6, ymm0, 1
	vaddpd	xmm0, xmm0, xmm6
	vshufpd	xmm6, xmm0, xmm0, 1             # xmm6 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm6
	cmp	rax, rdi
	je	.LBB0_56
.LBB0_54:                               # %L368.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	rsi, r13
	add	rdx, rsi
	.p2align	4
.LBB0_55:                               # %L368
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm6, qword ptr [rcx + 8*rdi]   # xmm6 = mem[0],zero
	vmulsd	xmm7, xmm4, qword ptr [rdx + 8*rdi]
	lea	rsi, [rdi + 1]
	vsubsd	xmm6, xmm6, xmm7
	vfmadd231sd	xmm0, xmm6, xmm6        # xmm0 = (xmm6 * xmm6) + xmm0
	mov	rdi, rsi
	cmp	rax, rsi
	jne	.LBB0_55
.LBB0_56:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm0, xmm5
	jb	.LBB0_58
# %bb.57:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm5, xmm0, xmm0
	vucomisd	xmm5, xmm5
	jp	.LBB0_58
.LBB0_59:                               # %L483
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm13, xmm0
	ja	.LBB0_77
# %bb.60:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm5, xmm1, xmm2
	vucomisd	xmm13, xmm5
	movabs	rax, offset .LCPI0_5
	ja	.LBB0_78
# %bb.61:                               # %L495
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm6, xmm1, xmm2
	vucomisd	xmm13, xmm6
	ja	.LBB0_79
# %bb.62:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm4, xmm4, xmm3
	vsqrtsd	xmm3, xmm0, xmm0
	vsqrtsd	xmm0, xmm5, xmm5
	vsqrtsd	xmm5, xmm6, xmm6
	vmulsd	xmm0, xmm0, xmm5
	vmulsd	xmm0, xmm1, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_68
# %bb.63:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm0, xmm3, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_68
# %bb.64:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rcx, offset .LCPI0_6
	vmovsd	xmm5, qword ptr [rcx]           # xmm5 = mem[0],zero
	vucomisd	xmm5, xmm0
	jb	.LBB0_68
# %bb.65:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulsd	xmm0, xmm2, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_68
# %bb.66:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm5, xmm0
	jb	.LBB0_68
# %bb.67:                               # %L535
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_7
	vxorpd	xmm1, xmm0, xmmword ptr [rax]
	vmaxsd	xmm1, xmm4, xmm1
	vminsd	xmm0, xmm1, xmm0
	vsubsd	xmm0, xmm4, xmm0
	vaddsd	xmm4, xmm13, xmm0
	jmp	.LBB0_70
.LBB0_68:                               # %L576
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 48], r12
	vmovapd	xmm0, xmm4
	xor	edi, edi
	vmovsd	qword ptr [rsp + 16], xmm15     # 8-byte Spill
	movabs	rax, offset j__sqrt_band_step_1519
	vzeroupper
	call	rax
	mov	r11, qword ptr [rsp + 24]       # 8-byte Reload
	vxorpd	xmm13, xmm13, xmm13
	vmovsd	xmm15, qword ptr [rsp + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vmovapd	xmm4, xmm0
	jmp	.LBB0_70
.LBB0_58:                               # %L481
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 48], r12
	mov	rdi, r14
	vmovapd	xmm0, xmm3
	mov	rsi, r15
	vmovsd	qword ptr [rsp + 16], xmm15     # 8-byte Spill
	movabs	rax, offset j__sqrt_offrange_step_1520
	vzeroupper
	call	rax
	mov	r11, qword ptr [rsp + 24]       # 8-byte Reload
	vxorpd	xmm13, xmm13, xmm13
	vmovsd	xmm15, qword ptr [rsp + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vmovapd	xmm4, xmm0
	jmp	.LBB0_70
.LBB0_8:                                # %L58
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_9
# %bb.10:                               # %L65.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 8
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_15
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_32
.LBB0_12:                               # %vector.ph503
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775792
	add	rdi, 8
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm2, ymmword ptr [rsp + 96]    # 32-byte Reload
	vmovapd	ymm5, ymm2
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm2
	vmovapd	ymm1, ymm0
.LBB0_13:                               # %vector.body506
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm6, ymmword ptr [r9 + 8*r10 - 32]
	vmovupd	ymm7, ymmword ptr [r9 + 8*r10]
	vmovupd	ymm8, ymmword ptr [rsi + 8*r10]
	vmovupd	ymm9, ymmword ptr [rsi + 8*r10 + 32]
	vfmadd231pd	ymm0, ymm6, ymm6        # ymm0 = (ymm6 * ymm6) + ymm0
	vfmadd231pd	ymm5, ymm7, ymm7        # ymm5 = (ymm7 * ymm7) + ymm5
	vfmadd231pd	ymm3, ymm8, ymm6        # ymm3 = (ymm8 * ymm6) + ymm3
	vfmadd231pd	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231pd	ymm1, ymm8, ymm8        # ymm1 = (ymm8 * ymm8) + ymm1
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	add	r10, 8
	cmp	rdi, r10
	jne	.LBB0_13
# %bb.14:                               # %middle.block501
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm5, ymm0
	vextractf128	xmm5, ymm0, 1
	vaddpd	xmm0, xmm0, xmm5
	vshufpd	xmm5, xmm0, xmm0, 1             # xmm5 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm5
	vaddpd	ymm3, ymm4, ymm3
	vextractf128	xmm4, ymm3, 1
	vaddpd	xmm3, xmm3, xmm4
	vshufpd	xmm4, xmm3, xmm3, 1             # xmm4 = xmm3[1,0]
	vaddsd	xmm6, xmm3, xmm4
	vaddpd	ymm1, ymm2, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddsd	xmm7, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_32
.LBB0_15:                               # %L71.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
.LBB0_16:                               # %L71
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [rdx + 8*rdi]   # xmm1 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231sd	xmm6, xmm2, xmm1        # xmm6 = (xmm2 * xmm1) + xmm6
	vfmadd231sd	xmm7, xmm2, xmm2        # xmm7 = (xmm2 * xmm2) + xmm7
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_16
	jmp	.LBB0_32
	.p2align	4
.LBB0_71:                               # %L593
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rsp + 72]       # 8-byte Reload
	cmp	rax, qword ptr [rsp + 64]       # 8-byte Folded Reload
	je	.LBB0_72
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r11, qword ptr [rbx + 16]
	jmp	.LBB0_4
.LBB0_72:
	mov	rcx, qword ptr [rsp + 56]       # 8-byte Reload
.LBB0_73:                               # %L604
	mov	rax, qword ptr [rsp + 40]
	mov	qword ptr [rcx], rax
	vmovapd	xmm0, xmm15
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_75:                               # %L307
	mov	qword ptr [rsp + 88], r15
	movabs	rax, offset j_throw_boundserror_1512
	lea	rsi, [rsp + 88]
	mov	rdi, rbx
	vzeroupper
	call	rax
.LBB0_74:                               # %L47
	mov	qword ptr [rsp + 80], r15
	mov	qword ptr [rsp + 48], rdi
	movabs	rax, offset j_throw_boundserror_1512
	lea	rsi, [rsp + 80]
	vzeroupper
	call	rax
.LBB0_76:                               # %L341
	movabs	rdi, offset ".Ljl_sym#sqrt#1517.jit"
	movabs	rax, offset j_throw_complex_domainerror_1516
	vzeroupper
	call	rax
.LBB0_77:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#1517.jit"
	movabs	rax, offset j_throw_complex_domainerror_1516
                                        # kill: def $xmm0 killed $xmm0 killed $ymm0
	vzeroupper
	call	rax
.LBB0_78:                               # %L493
	movabs	rdi, offset ".Ljl_sym#sqrt#1517.jit"
	movabs	rax, offset j_throw_complex_domainerror_1516
	vmovapd	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_79:                               # %L500
	movabs	rdi, offset ".Ljl_sym#sqrt#1517.jit"
	movabs	rax, offset j_throw_complex_domainerror_1516
	vmovapd	xmm0, xmm6
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1509, .Lfunc_end0-julia_pass_1509
                                        # -- End function
	.type	".L+Core.Float64#1511",@object  # @"+Core.Float64#1511"
	.section	.lrodata,"al",@progbits
	.p2align	3, 0x0
".L+Core.Float64#1511":
	.quad	".L+Core.Float64#1511.jit"
	.size	".L+Core.Float64#1511", 8

.set ".Ljl_sym#sqrt#1517.jit", 131248270530416
	.size	".Ljl_sym#sqrt#1517.jit", 8
.set ".L+Core.Float64#1511.jit", 131248414322624
	.size	".L+Core.Float64#1511.jit", 8
	.section	".note.GNU-stack","",@progbits
