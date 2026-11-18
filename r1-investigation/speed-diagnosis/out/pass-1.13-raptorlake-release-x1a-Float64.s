	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia_pass_2490
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
.LCPI0_5:
	.quad	0x7fefffffffffffff              # double 1.7976931348623157E+308
.LCPI0_6:
	.quad	0x0010000000000000              # double 2.2250738585072014E-308
.LCPI0_7:
	.quad	0x3ff0000000000000              # double 1
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
.LCPI0_8:
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.section	.ltext,"axl",@progbits
	.globl	julia_pass_2490
	.p2align	4
	.type	julia_pass_2490,@function
julia_pass_2490:                        # @julia_pass_2490
; Function Signature: pass(typeof(M_x1a.ProximalSolvers._column_dot_rsqr), typeof(M_x1a.ProximalSolvers._sqrt_minimizer), M_x1a.ProximalSolvers.SqrtLSModel{Float64, M_x1a.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
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
	sub	rsp, 288
	vxorpd	xmm0, xmm0, xmm0
	vmovupd	ymmword ptr [rsp + 48], ymm0
	mov	qword ptr [rsp + 88], 0
	mov	qword ptr [rsp + 80], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rsp + 48], 16
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rsp + 56], rax
	lea	rax, [rsp + 48]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorpd	xmm13, xmm13, xmm13
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rsp + 112], rax      # 8-byte Spill
	jle	.LBB0_73
# %bb.1:                                # %L17.preheader
	mov	r11, rsi
	mov	r14, qword ptr [rsi + 16]
	test	r14, r14
	jle	.LBB0_73
# %bb.2:                                # %L17.preheader4
	mov	r10, rdi
	mov	qword ptr [rsp + 104], rcx      # 8-byte Spill
	mov	r13, qword ptr [rdi]
	vxorpd	xmm15, xmm15, xmm15
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rcx]
	vmovapd	ymmword ptr [rsp + 224], ymm0   # 32-byte Spill
	mov	qword ptr [rsp + 40], r11       # 8-byte Spill
	mov	qword ptr [rsp + 24], rdi       # 8-byte Spill
	.p2align	4
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_13 Depth 3
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_29 Depth 3
                                        #       Child Loop BB0_32 Depth 3
                                        #       Child Loop BB0_49 Depth 3
                                        #       Child Loop BB0_53 Depth 3
                                        #       Child Loop BB0_56 Depth 3
	mov	qword ptr [rsp + 120], rax      # 8-byte Spill
	test	r14, r14
	jle	.LBB0_71
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15d, 1
	xor	r12d, r12d
	jmp	.LBB0_6
	.p2align	4
.LBB0_69:                               # %L561
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 72], rdi
	mov	qword ptr [rsp + 88], r13
	mov	qword ptr [rsp + 80], rcx
	mov	rdi, r10
	lea	rsi, [rsp + 168]
	lea	rdx, [rsp + 72]
	lea	r8, [rsp + 96]
	mov	r9, r15
	vmovsd	qword ptr [rsp + 32], xmm13     # 8-byte Spill
	movabs	rax, offset j__sqrt_cold_2501
	vzeroupper
	call	rax
	vmovsd	xmm13, qword ptr [rsp + 32]     # 8-byte Reload
                                        # xmm13 = mem[0],zero
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	mov	r11, qword ptr [rsp + 40]       # 8-byte Reload
	vmovapd	xmm3, xmm0
.LBB0_70:                               # %L565
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm13, xmm13, xmm3
	lea	rax, [r15 + 1]
	add	r12, 8
	cmp	r15, r14
	mov	r15, rax
	je	.LBB0_71
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_13 Depth 3
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_29 Depth 3
                                        #       Child Loop BB0_32 Depth 3
                                        #       Child Loop BB0_49 Depth 3
                                        #       Child Loop BB0_53 Depth 3
                                        #       Child Loop BB0_56 Depth 3
	mov	rdi, qword ptr [r13 + 32]
	lea	rax, [r15 - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_74
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r13]
	mov	rsi, qword ptr [r13 + 24]
	mov	rcx, qword ptr [rdi]
	vmovsd	xmm1, qword ptr [rcx + 8*r15 - 8] # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm1
	mov	rcx, qword ptr [rsi + 16]
	jp	.LBB0_8
# %bb.17:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_18
# %bb.19:                               # %iter.check599
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_21
# %bb.20:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm4, xmm4, xmm4
	xor	edi, edi
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_31
	.p2align	4
.LBB0_18:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_33
	.p2align	4
.LBB0_21:                               # %vector.main.loop.iter.check601
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 16
	jae	.LBB0_23
# %bb.22:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm4, xmm4, xmm4
	xor	edi, edi
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_28
.LBB0_23:                               # %vector.ph602
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	r9, 9223372036854775792
	and	rdi, r9
	mov	r9, r8
	imul	r9, r12
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm3, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm4, ymm0
	vmovapd	ymm8, ymm0
	vmovapd	ymm2, ymm3
	vmovapd	ymm5, ymm0
	vmovapd	ymm6, ymm0
	vmovapd	ymm7, ymm0
	.p2align	4
.LBB0_24:                               # %vector.body605
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm9, ymmword ptr [rsi + 8*r10]
	vmovupd	ymm10, ymmword ptr [rsi + 8*r10 + 32]
	vmovupd	ymm11, ymmword ptr [rsi + 8*r10 + 64]
	vmovupd	ymm12, ymmword ptr [rsi + 8*r10 + 96]
	vfmadd231pd	ymm3, ymm9, ymmword ptr [r9 + 8*r10 - 96] # ymm3 = (ymm9 * mem) + ymm3
	vfmadd231pd	ymm0, ymm10, ymmword ptr [r9 + 8*r10 - 64] # ymm0 = (ymm10 * mem) + ymm0
	vfmadd231pd	ymm4, ymm11, ymmword ptr [r9 + 8*r10 - 32] # ymm4 = (ymm11 * mem) + ymm4
	vfmadd231pd	ymm8, ymm12, ymmword ptr [r9 + 8*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vfmadd231pd	ymm5, ymm10, ymm10      # ymm5 = (ymm10 * ymm10) + ymm5
	vfmadd231pd	ymm6, ymm11, ymm11      # ymm6 = (ymm11 * ymm11) + ymm6
	vfmadd231pd	ymm7, ymm12, ymm12      # ymm7 = (ymm12 * ymm12) + ymm7
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_24
# %bb.25:                               # %middle.block596
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm0, ymm3
	vaddpd	ymm0, ymm4, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddsd	xmm4, xmm0, xmm3
	vaddpd	ymm0, ymm5, ymm2
	vaddpd	ymm0, ymm6, ymm0
	vaddpd	ymm0, ymm7, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm5, xmm0, xmm2
	cmp	rcx, rdi
	jne	.LBB0_27
# %bb.26:                               #   in Loop: Header=BB0_6 Depth=2
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	jmp	.LBB0_33
.LBB0_27:                               # %vec.epilog.iter.check637
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	je	.LBB0_31
.LBB0_28:                               # %vec.epilog.ph636
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	movabs	rdi, 9223372036854775792
	add	rdi, 12
	and	rdi, rcx
	vmovapd	ymm0, ymmword ptr [rsp + 224]   # 32-byte Reload
	vblendpd	ymm2, ymm0, ymm4, 1             # ymm2 = ymm4[0],ymm0[1,2,3]
	vblendpd	ymm0, ymm0, ymm5, 1             # ymm0 = ymm5[0],ymm0[1,2,3]
	mov	r10, r8
	imul	r10, r12
	add	r10, rdx
	.p2align	4
.LBB0_29:                               # %vec.epilog.vector.body642
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm3, ymmword ptr [rsi + 8*r9]
	vfmadd231pd	ymm2, ymm3, ymmword ptr [r10 + 8*r9] # ymm2 = (ymm3 * mem) + ymm2
	vfmadd231pd	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_29
# %bb.30:                               # %vec.epilog.middle.block634
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddsd	xmm4, xmm2, xmm3
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm5, xmm0, xmm2
	cmp	rcx, rdi
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	je	.LBB0_33
.LBB0_31:                               # %L190.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r12
	add	rdx, r8
	.p2align	4
.LBB0_32:                               # %L190
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [rsi + 8*rdi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm4, xmm0, qword ptr [rdx + 8*rdi] # xmm4 = (xmm0 * mem) + xmm4
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm5, xmm0, xmm0        # xmm5 = (xmm0 * xmm0) + xmm5
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_32
.LBB0_33:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [r11 + 16]
	jae	.LBB0_75
# %bb.34:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [r10]
	mov	rdi, qword ptr [rcx]
	mov	rdx, qword ptr [rdi + 16]
	cmp	rax, qword ptr [rdi + 24]
	jae	.LBB0_76
# %bb.35:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [r11]
	vmovsd	xmm0, qword ptr [rsi + 8*r15 - 8] # xmm0 = mem[0],zero
	imul	rax, rdx
	mov	qword ptr [rsp + 176], rdx
	mov	qword ptr [rsp + 184], r15
	mov	qword ptr [rsp + 192], rax
	mov	qword ptr [rsp + 200], 1
	mov	rcx, qword ptr [rcx + 24]
	mov	rbx, qword ptr [r10 + 8]
	mov	qword ptr [rsp + 96], rbx
	vsubsd	xmm2, xmm1, xmm1
	vucomisd	xmm2, xmm2
	jp	.LBB0_69
# %bb.36:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rcx + 16]
	vxorps	xmm14, xmm14, xmm14
	vcvtsi2sd	xmm2, xmm14, rax
	movabs	rsi, offset .LCPI0_2
	vmulsd	xmm2, xmm2, qword ptr [rsi]
	vucomisd	xmm1, xmm2
	jb	.LBB0_69
# %bb.37:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm3, xmm5, xmm5
	vucomisd	xmm3, xmm3
	jp	.LBB0_69
# %bb.38:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm5, xmm2
	jb	.LBB0_69
# %bb.39:                               # %L378
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm1
	ja	.LBB0_77
# %bb.40:                               # %L383
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovq	xmm6, rbx
	vsqrtsd	xmm7, xmm1, xmm1
	vxorpd	xmm3, xmm3, xmm3
	vucomisd	xmm6, xmm7
	jae	.LBB0_70
# %bb.41:                               # %L387
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm2, xmm4, xmm1
	vmulsd	xmm3, xmm4, xmm2
	vsubsd	xmm3, xmm5, xmm3
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm4, xmm5, qword ptr [rsi]
	vucomisd	xmm4, xmm3
	vmovsd	qword ptr [rsp + 32], xmm13     # 8-byte Spill
	jbe	.LBB0_57
# %bb.42:                               # %L394
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	jle	.LBB0_43
# %bb.44:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	r8, qword ptr [rdi]
	cmp	rax, 4
	jae	.LBB0_46
# %bb.45:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	xor	r9d, r9d
	jmp	.LBB0_55
.LBB0_43:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_58
.LBB0_46:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, 15
	ja	.LBB0_48
# %bb.47:                               # %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
                                        #   in Loop: Header=BB0_6 Depth=2
	vbroadcastsd	ymm4, xmm2
	vxorpd	xmm3, xmm3, xmm3
	xor	r9d, r9d
	jmp	.LBB0_52
.LBB0_48:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rax
	movabs	r10, 9223372036854775792
	and	r9, r10
	vbroadcastsd	ymm4, xmm2
	mov	r10, rdx
	imul	r10, r12
	add	r10, r8
	add	r10, 96
	movabs	r11, offset .LCPI0_0
	vbroadcastsd	ymm3, qword ptr [r11]
	movabs	r11, offset .LCPI0_1
	vmovapd	ymm5, ymmword ptr [r11]
	xor	r11d, r11d
	vmovapd	ymm8, ymm3
	vmovapd	ymm9, ymm3
	.p2align	4
.LBB0_49:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm10, ymmword ptr [rsi + 8*r11]
	vmovupd	ymm11, ymmword ptr [rsi + 8*r11 + 32]
	vmovupd	ymm12, ymmword ptr [rsi + 8*r11 + 64]
	vmovupd	ymm13, ymmword ptr [rsi + 8*r11 + 96]
	vmulpd	ymm14, ymm4, ymmword ptr [r10 + 8*r11 - 96]
	vsubpd	ymm10, ymm10, ymm14
	vmulpd	ymm14, ymm4, ymmword ptr [r10 + 8*r11 - 64]
	vsubpd	ymm11, ymm11, ymm14
	vmulpd	ymm14, ymm4, ymmword ptr [r10 + 8*r11 - 32]
	vsubpd	ymm12, ymm12, ymm14
	vmulpd	ymm14, ymm4, ymmword ptr [r10 + 8*r11]
	vsubpd	ymm13, ymm13, ymm14
	vfmadd231pd	ymm5, ymm10, ymm10      # ymm5 = (ymm10 * ymm10) + ymm5
	vfmadd231pd	ymm3, ymm11, ymm11      # ymm3 = (ymm11 * ymm11) + ymm3
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	vfmadd231pd	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	r11, 16
	cmp	r9, r11
	jne	.LBB0_49
# %bb.50:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm3, ymm3, ymm5
	vaddpd	ymm3, ymm8, ymm3
	vaddpd	ymm3, ymm9, ymm3
	vextractf128	xmm5, ymm3, 1
	vaddpd	xmm3, xmm3, xmm5
	vshufpd	xmm5, xmm3, xmm3, 1             # xmm5 = xmm3[1,0]
	vaddsd	xmm3, xmm3, xmm5
	cmp	rax, r9
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	je	.LBB0_57
# %bb.51:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	al, 12
	je	.LBB0_55
.LBB0_52:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r10, r9
	movabs	r9, 9223372036854775792
	add	r9, 12
	and	r9, rax
	movabs	r11, offset .LCPI0_4
	vblendpd	ymm3, ymm3, ymmword ptr [r11], 14 # ymm3 = ymm3[0],mem[1,2,3]
	mov	r11, rdx
	imul	r11, r12
	add	r11, r8
	.p2align	4
.LBB0_53:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm5, ymmword ptr [rsi + 8*r10]
	vmulpd	ymm8, ymm4, ymmword ptr [r11 + 8*r10]
	vsubpd	ymm5, ymm5, ymm8
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	add	r10, 4
	cmp	r9, r10
	jne	.LBB0_53
# %bb.54:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm4, ymm3, 1
	vaddpd	xmm3, xmm3, xmm4
	vshufpd	xmm4, xmm3, xmm3, 1             # xmm4 = xmm3[1,0]
	vaddsd	xmm3, xmm3, xmm4
	cmp	rax, r9
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	je	.LBB0_57
.LBB0_55:                               # %L405.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	rdx, r12
	add	r8, rdx
	.p2align	4
.LBB0_56:                               # %L405
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm4, qword ptr [rsi + 8*r9]    # xmm4 = mem[0],zero
	vmulsd	xmm5, xmm2, qword ptr [r8 + 8*r9]
	lea	rdx, [r9 + 1]
	vsubsd	xmm4, xmm4, xmm5
	vfmadd231sd	xmm3, xmm4, xmm4        # xmm3 = (xmm4 * xmm4) + xmm3
	mov	r9, rdx
	cmp	rax, rdx
	jne	.LBB0_56
.LBB0_57:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm3
	ja	.LBB0_78
.LBB0_58:                               # %L476
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm4, xmm7, xmm6
	vucomisd	xmm15, xmm4
	ja	.LBB0_79
# %bb.59:                               # %L482
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm5, xmm7, xmm6
	vucomisd	xmm15, xmm5
	ja	.LBB0_80
# %bb.60:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtsd	xmm4, xmm4, xmm4
	vsqrtsd	xmm5, xmm5, xmm5
	vmulsd	xmm4, xmm4, xmm5
	vmulsd	xmm5, xmm7, xmm4
	vucomisd	xmm3, xmm15
	setnp	dl
	sete	al
	movabs	rsi, offset .LCPI0_6
	vmovsd	xmm4, qword ptr [rsi]           # xmm4 = mem[0],zero
	vucomisd	xmm5, xmm4
	jb	.LBB0_68
# %bb.61:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtsd	xmm3, xmm3, xmm3
	vdivsd	xmm9, xmm3, xmm5
	vmulsd	xmm3, xmm9, xmm6
	and	al, dl
	movabs	rdx, offset .LCPI0_5
	vmovsd	xmm5, qword ptr [rdx]           # xmm5 = mem[0],zero
	vcmplepd	xmm7, xmm9, xmm5
	vcmplepd	xmm8, xmm4, xmm9
	vandpd	xmm7, xmm8, xmm7
	vcmplepd	xmm5, xmm3, xmm5
	vcmplepd	xmm4, xmm4, xmm3
	vandpd	xmm4, xmm4, xmm5
	vmovq	rdx, xmm4
	vmovd	esi, xmm7
	mov	r8d, edx
	and	r8d, esi
	or	r8b, al
	test	r8b, 1
	je	.LBB0_68
# %bb.62:                               # %L511
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm1, xmm2, xmm0
	test	dl, 1
	je	.LBB0_64
# %bb.63:                               # %L521
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_8
	vxorpd	xmm0, xmm3, xmmword ptr [rax]
	vmaxsd	xmm0, xmm1, xmm0
	vminsd	xmm0, xmm0, xmm3
	vsubsd	xmm0, xmm1, xmm0
	vaddsd	xmm3, xmm15, xmm0
	mov	r11, qword ptr [rsp + 40]       # 8-byte Reload
	vmovsd	xmm13, qword ptr [rsp + 32]     # 8-byte Reload
                                        # xmm13 = mem[0],zero
	jmp	.LBB0_70
.LBB0_68:                               # %L559
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 64], rdi
	mov	qword ptr [rsp + 88], r13
	mov	qword ptr [rsp + 80], rcx
	mov	rdi, r10
	lea	rsi, [rsp + 168]
	lea	rdx, [rsp + 64]
	lea	r8, [rsp + 96]
	mov	r9, r15
	movabs	rax, offset j__sqrt_cold_2501
	vzeroupper
	call	rax
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	vmovapd	xmm3, xmm0
	mov	r11, qword ptr [rsp + 40]       # 8-byte Reload
	vmovsd	xmm13, qword ptr [rsp + 32]     # 8-byte Reload
                                        # xmm13 = mem[0],zero
	jmp	.LBB0_70
.LBB0_64:                               # %L541
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 88], r13
	movabs	rax, offset .LCPI0_7
	vmovsd	xmm2, qword ptr [rax]           # xmm2 = mem[0],zero
	vmovapd	xmm0, xmm9
	vmovsd	qword ptr [rsp + 128], xmm1     # 8-byte Spill
	vmovapd	xmm1, xmm6
	movabs	rax, offset j__exceptional_product_2500
	vmovapd	xmmword ptr [rsp + 208], xmm9   # 16-byte Spill
	vzeroupper
	call	rax
	vxorpd	xmm15, xmm15, xmm15
	vmovsd	xmm4, qword ptr [rsp + 128]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vsubsd	xmm1, xmm4, xmm0
	vcmpunordsd	xmm2, xmm1, xmm1
	vmaxsd	xmm3, xmm1, xmm15
	vblendvpd	xmm1, xmm3, xmm1, xmm2
	vaddsd	xmm0, xmm4, xmm0
	vminsd	xmm0, xmm15, xmm0
	vaddsd	xmm3, xmm1, xmm0
	mov	al, 63
	bzhi	rax, rbx, rax
	movabs	rcx, 9218868437227405312
	cmp	rax, rcx
	je	.LBB0_65
# %bb.66:                               # %L541
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r11, qword ptr [rsp + 40]       # 8-byte Reload
	vmovsd	xmm13, qword ptr [rsp + 32]     # 8-byte Reload
                                        # xmm13 = mem[0],zero
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	jmp	.LBB0_70
.LBB0_65:                               #   in Loop: Header=BB0_6 Depth=2
	vcmpnlesd	xmm0, xmm15, qword ptr [rsp + 208] # 16-byte Folded Reload
	vandpd	xmm3, xmm0, xmm3
	mov	r11, qword ptr [rsp + 40]       # 8-byte Reload
	vmovsd	xmm13, qword ptr [rsp + 32]     # 8-byte Reload
                                        # xmm13 = mem[0],zero
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
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
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_15
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_33
.LBB0_12:                               # %vector.ph655
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775792
	add	rdi, 8
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r12
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm2, ymmword ptr [rsp + 224]   # 32-byte Reload
	vmovapd	ymm5, ymm2
	vmovapd	ymm3, ymm1
	vmovapd	ymm4, ymm2
	vmovapd	ymm0, ymm1
.LBB0_13:                               # %vector.body658
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm6, ymmword ptr [r9 + 8*r10 - 32]
	vmovupd	ymm7, ymmword ptr [r9 + 8*r10]
	vmovupd	ymm8, ymmword ptr [rsi + 8*r10]
	vmovupd	ymm9, ymmword ptr [rsi + 8*r10 + 32]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm5, ymm7, ymm7        # ymm5 = (ymm7 * ymm7) + ymm5
	vfmadd231pd	ymm3, ymm8, ymm6        # ymm3 = (ymm8 * ymm6) + ymm3
	vfmadd231pd	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231pd	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	add	r10, 8
	cmp	rdi, r10
	jne	.LBB0_13
# %bb.14:                               # %middle.block653
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm1, ymm5, ymm1
	vextractf128	xmm5, ymm1, 1
	vaddpd	xmm1, xmm1, xmm5
	vshufpd	xmm5, xmm1, xmm1, 1             # xmm5 = xmm1[1,0]
	vaddsd	xmm1, xmm1, xmm5
	vaddpd	ymm3, ymm4, ymm3
	vextractf128	xmm4, ymm3, 1
	vaddpd	xmm3, xmm3, xmm4
	vshufpd	xmm4, xmm3, xmm3, 1             # xmm4 = xmm3[1,0]
	vaddsd	xmm4, xmm3, xmm4
	vaddpd	ymm0, ymm2, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm5, xmm0, xmm2
	cmp	rcx, rdi
	mov	r10, qword ptr [rsp + 24]       # 8-byte Reload
	je	.LBB0_33
.LBB0_15:                               # %L71.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r12
	add	rdx, r8
.LBB0_16:                               # %L71
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [rdx + 8*rdi]   # xmm0 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm4, xmm2, xmm0        # xmm4 = (xmm2 * xmm0) + xmm4
	vfmadd231sd	xmm5, xmm2, xmm2        # xmm5 = (xmm2 * xmm2) + xmm5
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_16
	jmp	.LBB0_33
	.p2align	4
.LBB0_71:                               # %L577
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rsp + 120]      # 8-byte Reload
	cmp	rax, qword ptr [rsp + 112]      # 8-byte Folded Reload
	je	.LBB0_72
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r14, qword ptr [r11 + 16]
	jmp	.LBB0_4
.LBB0_72:
	mov	rcx, qword ptr [rsp + 104]      # 8-byte Reload
.LBB0_73:                               # %L588
	mov	rax, qword ptr [rsp + 56]
	mov	qword ptr [rcx], rax
	vmovapd	xmm0, xmm13
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
	mov	qword ptr [rsp + 144], r15
	movabs	rax, offset j_throw_boundserror_2493
	lea	rsi, [rsp + 144]
	mov	rdi, r11
	vzeroupper
	call	rax
.LBB0_76:                               # %L341
	mov	qword ptr [rsp + 160], r15
	mov	qword ptr [rsp + 152], rdx
	mov	qword ptr [rsp + 80], rdi
	movabs	rax, offset j_throw_boundserror_2502
	lea	rsi, [rsp + 152]
	vzeroupper
	call	rax
.LBB0_74:                               # %L47
	mov	qword ptr [rsp + 136], r15
	mov	qword ptr [rsp + 80], rdi
	movabs	rax, offset j_throw_boundserror_2493
	lea	rsi, [rsp + 136]
	vzeroupper
	call	rax
.LBB0_77:                               # %L381
	movabs	rdi, offset ".Ljl_sym#sqrt#2498.jit"
	movabs	rax, offset j_throw_complex_domainerror_2497
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_79:                               # %L480
	movabs	rdi, offset ".Ljl_sym#sqrt#2498.jit"
	movabs	rax, offset j_throw_complex_domainerror_2497
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_80:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#2498.jit"
	movabs	rax, offset j_throw_complex_domainerror_2497
	vmovapd	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_78:                               # %L474
	movabs	rdi, offset ".Ljl_sym#sqrt#2498.jit"
	movabs	rax, offset j_throw_complex_domainerror_2497
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_2490, .Lfunc_end0-julia_pass_2490
                                        # -- End function
	.type	".L+Core.Float64#2492",@object  # @"+Core.Float64#2492"
	.section	.lrodata,"al",@progbits
	.p2align	3, 0x0
".L+Core.Float64#2492":
	.quad	".L+Core.Float64#2492.jit"
	.size	".L+Core.Float64#2492", 8

.set ".Ljl_sym#sqrt#2498.jit", 131248270530416
	.size	".Ljl_sym#sqrt#2498.jit", 8
.set ".L+Core.Float64#2492.jit", 131248414322624
	.size	".L+Core.Float64#2492.jit", 8
	.section	".note.GNU-stack","",@progbits
