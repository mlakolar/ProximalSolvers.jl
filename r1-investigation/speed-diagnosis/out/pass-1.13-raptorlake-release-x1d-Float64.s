	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia_pass_2126
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
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
	.section	.ltext,"axl",@progbits
	.globl	julia_pass_2126
	.p2align	4
	.type	julia_pass_2126,@function
julia_pass_2126:                        # @julia_pass_2126
; Function Signature: pass(typeof(M_x1d.ProximalSolvers._column_dot_rsqr), typeof(M_x1d.ProximalSolvers._sqrt_minimizer), M_x1d.ProximalSolvers.SqrtLSModel{Float64, M_x1d.ProximalSolvers.LSModel{Float64, Float64, Array{Float64, 2}, Array{Float64, 1}}}, Array{Float64, 1}, Int64)
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
	vmovapd	xmmword ptr [rsp], xmm0
	mov	qword ptr [rsp + 16], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rsp], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rsp + 8], rax
	mov	rax, rsp
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorpd	xmm14, xmm14, xmm14
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rsp + 32], rax       # 8-byte Spill
	jle	.LBB0_64
# %bb.1:                                # %L17.preheader
	mov	rbx, rsi
	mov	r11, qword ptr [rsi + 16]
	test	r11, r11
	jle	.LBB0_64
# %bb.2:                                # %L17.preheader4
	mov	r14, rdi
	mov	qword ptr [rsp + 24], rcx       # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorpd	xmm15, xmm15, xmm15
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
                                        #       Child Loop BB0_48 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_55 Depth 3
	mov	qword ptr [rsp + 40], rax       # 8-byte Spill
	test	r11, r11
	jle	.LBB0_62
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	esi, 1
	xor	r13d, r13d
	jmp	.LBB0_6
	.p2align	4
.LBB0_60:                               # %L506
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rsp + 16], r12
	mov	rdi, r14
	vmovsd	qword ptr [rsp + 56], xmm14     # 8-byte Spill
	mov	qword ptr [rsp + 48], rsi       # 8-byte Spill
	mov	r15, r13
	mov	r13, r12
	mov	r12, rbx
	mov	rbx, r14
	mov	r14, r11
	movabs	rax, offset j__sqrt_cold_2137
	vzeroupper
	call	rax
	mov	r11, r14
	mov	r14, rbx
	mov	rbx, r12
	mov	r12, r13
	mov	r13, r15
	mov	rsi, qword ptr [rsp + 48]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	vmovsd	xmm14, qword ptr [rsp + 56]     # 8-byte Reload
                                        # xmm14 = mem[0],zero
	vmovapd	xmm2, xmm0
.LBB0_61:                               # %L510
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm14, xmm14, xmm2
	lea	rax, [rsi + 1]
	add	r13, 8
	cmp	rsi, r11
	mov	rsi, rax
	je	.LBB0_62
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_13 Depth 3
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_48 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_55 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	rax, [rsi - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_65
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r12]
	mov	r9, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovsd	xmm1, qword ptr [rcx + 8*rsi - 8] # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm1
	mov	rcx, qword ptr [r9 + 16]
	jp	.LBB0_8
# %bb.17:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_18
# %bb.19:                               # %iter.check561
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	r15, qword ptr [r9]
	cmp	rcx, 4
	jae	.LBB0_21
# %bb.20:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_30
	.p2align	4
.LBB0_18:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_32
	.p2align	4
.LBB0_21:                               # %vector.main.loop.iter.check563
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 16
	jae	.LBB0_23
# %bb.22:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_27
.LBB0_23:                               # %vector.ph564
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	r9, 9223372036854775792
	and	rdi, r9
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm3, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm7, ymm0
	vmovapd	ymm8, ymm0
	vmovapd	ymm2, ymm3
	vmovapd	ymm4, ymm0
	vmovapd	ymm5, ymm0
	vmovapd	ymm6, ymm0
	.p2align	4
.LBB0_24:                               # %vector.body567
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm9, ymmword ptr [r15 + 8*r10]
	vmovupd	ymm10, ymmword ptr [r15 + 8*r10 + 32]
	vmovupd	ymm11, ymmword ptr [r15 + 8*r10 + 64]
	vmovupd	ymm12, ymmword ptr [r15 + 8*r10 + 96]
	vfmadd231pd	ymm3, ymm9, ymmword ptr [r9 + 8*r10 - 96] # ymm3 = (ymm9 * mem) + ymm3
	vfmadd231pd	ymm0, ymm10, ymmword ptr [r9 + 8*r10 - 64] # ymm0 = (ymm10 * mem) + ymm0
	vfmadd231pd	ymm7, ymm11, ymmword ptr [r9 + 8*r10 - 32] # ymm7 = (ymm11 * mem) + ymm7
	vfmadd231pd	ymm8, ymm12, ymmword ptr [r9 + 8*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vfmadd231pd	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231pd	ymm5, ymm11, ymm11      # ymm5 = (ymm11 * ymm11) + ymm5
	vfmadd231pd	ymm6, ymm12, ymm12      # ymm6 = (ymm12 * ymm12) + ymm6
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_24
# %bb.25:                               # %middle.block558
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm0, ymm3
	vaddpd	ymm0, ymm7, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddsd	xmm3, xmm0, xmm3
	vaddpd	ymm0, ymm4, ymm2
	vaddpd	ymm0, ymm5, ymm0
	vaddpd	ymm0, ymm6, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm7, xmm0, xmm2
	cmp	rcx, rdi
	je	.LBB0_32
# %bb.26:                               # %vec.epilog.iter.check599
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	je	.LBB0_30
.LBB0_27:                               # %vec.epilog.ph598
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	movabs	rdi, 9223372036854775792
	add	rdi, 12
	and	rdi, rcx
	vmovapd	ymm0, ymmword ptr [rsp + 96]    # 32-byte Reload
	vblendpd	ymm2, ymm0, ymm3, 1             # ymm2 = ymm3[0],ymm0[1,2,3]
	vblendpd	ymm0, ymm0, ymm7, 1             # ymm0 = ymm7[0],ymm0[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
	.p2align	4
.LBB0_28:                               # %vec.epilog.vector.body604
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm3, ymmword ptr [r15 + 8*r9]
	vfmadd231pd	ymm2, ymm3, ymmword ptr [r10 + 8*r9] # ymm2 = (ymm3 * mem) + ymm2
	vfmadd231pd	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_28
# %bb.29:                               # %vec.epilog.middle.block596
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddsd	xmm3, xmm2, xmm3
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm7, xmm0, xmm2
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
	vmovsd	xmm0, qword ptr [r15 + 8*rdi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm3, xmm0, qword ptr [rdx + 8*rdi] # xmm3 = (xmm0 * mem) + xmm3
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm7, xmm0, xmm0        # xmm7 = (xmm0 * xmm0) + xmm7
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_31
.LBB0_32:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [rbx + 16]
	jae	.LBB0_66
# %bb.33:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rbx]
	vmovsd	xmm0, qword ptr [rcx + 8*rsi - 8] # xmm0 = mem[0],zero
	vsubsd	xmm2, xmm1, xmm1
	vucomisd	xmm2, xmm2
	jp	.LBB0_60
# %bb.34:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r14]
	mov	rdx, qword ptr [r8 + 24]
	mov	rcx, qword ptr [rdx + 16]
	vxorps	xmm13, xmm13, xmm13
	vcvtsi2sd	xmm2, xmm13, rcx
	movabs	rdi, offset .LCPI0_2
	vmulsd	xmm2, xmm2, qword ptr [rdi]
	vucomisd	xmm1, xmm2
	jb	.LBB0_60
# %bb.35:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm4, xmm7, xmm7
	vucomisd	xmm4, xmm4
	jp	.LBB0_60
# %bb.36:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm7, xmm2
	jb	.LBB0_60
# %bb.37:                               # %L341
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm1
	ja	.LBB0_67
# %bb.38:                               # %L345
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovsd	xmm4, qword ptr [r14 + 8]       # xmm4 = mem[0],zero
	vsqrtsd	xmm5, xmm1, xmm1
	vxorpd	xmm2, xmm2, xmm2
	vucomisd	xmm4, xmm5
	jae	.LBB0_61
# %bb.39:                               # %L350
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm6, xmm3, xmm1
	vmulsd	xmm1, xmm3, xmm6
	vsubsd	xmm1, xmm7, xmm1
	movabs	rdi, offset .LCPI0_3
	vmulsd	xmm2, xmm7, qword ptr [rdi]
	vucomisd	xmm2, xmm1
	jbe	.LBB0_56
# %bb.40:                               # %L356
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, qword ptr [r8]
	mov	r10, qword ptr [rdi + 16]
	cmp	rax, qword ptr [rdi + 24]
	jae	.LBB0_68
# %bb.41:                               # %L383
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_42
# %bb.43:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rdx]
	mov	rdx, qword ptr [rdi]
	cmp	rcx, 4
	jae	.LBB0_45
# %bb.44:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	jmp	.LBB0_54
.LBB0_42:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_57
.LBB0_45:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 15
	ja	.LBB0_47
# %bb.46:                               # %vector.main.loop.iter.check.vec.epilog.ph_crit_edge
                                        #   in Loop: Header=BB0_6 Depth=2
	vbroadcastsd	ymm2, xmm6
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	jmp	.LBB0_51
.LBB0_47:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	r8, 9223372036854775792
	and	rdi, r8
	vbroadcastsd	ymm2, xmm6
	mov	r8, r10
	imul	r8, r13
	add	r8, rdx
	add	r8, 96
	movabs	r9, offset .LCPI0_0
	vbroadcastsd	ymm1, qword ptr [r9]
	movabs	r9, offset .LCPI0_1
	vmovapd	ymm3, ymmword ptr [r9]
	xor	r9d, r9d
	vmovapd	ymm7, ymm1
	vmovapd	ymm8, ymm1
	.p2align	4
.LBB0_48:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm9, ymmword ptr [rax + 8*r9]
	vmovupd	ymm10, ymmword ptr [rax + 8*r9 + 32]
	vmovupd	ymm11, ymmword ptr [rax + 8*r9 + 64]
	vmovupd	ymm12, ymmword ptr [rax + 8*r9 + 96]
	vmulpd	ymm13, ymm2, ymmword ptr [r8 + 8*r9 - 96]
	vsubpd	ymm9, ymm9, ymm13
	vmulpd	ymm13, ymm2, ymmword ptr [r8 + 8*r9 - 64]
	vsubpd	ymm10, ymm10, ymm13
	vmulpd	ymm13, ymm2, ymmword ptr [r8 + 8*r9 - 32]
	vsubpd	ymm11, ymm11, ymm13
	vmulpd	ymm13, ymm2, ymmword ptr [r8 + 8*r9]
	vsubpd	ymm12, ymm12, ymm13
	vfmadd231pd	ymm3, ymm9, ymm9        # ymm3 = (ymm9 * ymm9) + ymm3
	vfmadd231pd	ymm1, ymm10, ymm10      # ymm1 = (ymm10 * ymm10) + ymm1
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	add	r9, 16
	cmp	rdi, r9
	jne	.LBB0_48
# %bb.49:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm1, ymm1, ymm3
	vaddpd	ymm1, ymm7, ymm1
	vaddpd	ymm1, ymm8, ymm1
	vextractf128	xmm3, ymm1, 1
	vaddpd	xmm1, xmm1, xmm3
	vshufpd	xmm3, xmm1, xmm1, 1             # xmm3 = xmm1[1,0]
	vaddsd	xmm1, xmm1, xmm3
	cmp	rcx, rdi
	je	.LBB0_56
# %bb.50:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	je	.LBB0_54
.LBB0_51:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, rdi
	movabs	rdi, 9223372036854775792
	add	rdi, 12
	and	rdi, rcx
	movabs	r9, offset .LCPI0_4
	vblendpd	ymm1, ymm1, ymmword ptr [r9], 14 # ymm1 = ymm1[0],mem[1,2,3]
	mov	r9, r10
	imul	r9, r13
	add	r9, rdx
	.p2align	4
.LBB0_52:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm3, ymmword ptr [rax + 8*r8]
	vmulpd	ymm7, ymm2, ymmword ptr [r9 + 8*r8]
	vsubpd	ymm3, ymm3, ymm7
	vfmadd231pd	ymm1, ymm3, ymm3        # ymm1 = (ymm3 * ymm3) + ymm1
	add	r8, 4
	cmp	rdi, r8
	jne	.LBB0_52
# %bb.53:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddsd	xmm1, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_56
.LBB0_54:                               # %L406.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r10, r13
	add	rdx, r10
	.p2align	4
.LBB0_55:                               # %L406
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm2, qword ptr [rax + 8*rdi]   # xmm2 = mem[0],zero
	vmulsd	xmm3, xmm6, qword ptr [rdx + 8*rdi]
	lea	r8, [rdi + 1]
	vsubsd	xmm2, xmm2, xmm3
	vfmadd231sd	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_55
.LBB0_56:                               # %L474
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm1
	ja	.LBB0_69
.LBB0_57:                               # %L481
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm2, xmm5, xmm4
	vucomisd	xmm15, xmm2
	ja	.LBB0_70
# %bb.58:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm3, xmm5, xmm4
	vucomisd	xmm15, xmm3
	ja	.LBB0_71
# %bb.59:                               # %L495
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm0, xmm6, xmm0
	vdivsd	xmm4, xmm4, xmm5
	vsqrtsd	xmm1, xmm1, xmm1
	vsqrtsd	xmm2, xmm2, xmm2
	vsqrtsd	xmm3, xmm3, xmm3
	vmulsd	xmm2, xmm2, xmm3
	vdivsd	xmm1, xmm1, xmm2
	vmulsd	xmm1, xmm4, xmm1
	vsubsd	xmm2, xmm0, xmm1
	vcmpunordsd	xmm3, xmm2, xmm2
	vmaxsd	xmm4, xmm2, xmm15
	vblendvpd	xmm2, xmm4, xmm2, xmm3
	vaddsd	xmm0, xmm0, xmm1
	vminsd	xmm0, xmm15, xmm0
	vaddsd	xmm2, xmm2, xmm0
	jmp	.LBB0_61
.LBB0_8:                                # %L58
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_9
# %bb.10:                               # %L65.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	r15, qword ptr [r9]
	cmp	rcx, 8
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_15
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_32
.LBB0_12:                               # %vector.ph617
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775792
	add	rdi, 8
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [r10]
	xor	r10d, r10d
	vmovapd	ymm2, ymmword ptr [rsp + 96]    # 32-byte Reload
	vmovapd	ymm5, ymm2
	vmovapd	ymm3, ymm1
	vmovapd	ymm4, ymm2
	vmovapd	ymm0, ymm1
.LBB0_13:                               # %vector.body620
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm6, ymmword ptr [r9 + 8*r10 - 32]
	vmovupd	ymm7, ymmword ptr [r9 + 8*r10]
	vmovupd	ymm8, ymmword ptr [r15 + 8*r10]
	vmovupd	ymm9, ymmword ptr [r15 + 8*r10 + 32]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm5, ymm7, ymm7        # ymm5 = (ymm7 * ymm7) + ymm5
	vfmadd231pd	ymm3, ymm8, ymm6        # ymm3 = (ymm8 * ymm6) + ymm3
	vfmadd231pd	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231pd	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	add	r10, 8
	cmp	rdi, r10
	jne	.LBB0_13
# %bb.14:                               # %middle.block615
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
	vaddsd	xmm3, xmm3, xmm4
	vaddpd	ymm0, ymm2, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddsd	xmm7, xmm0, xmm2
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
	vmovsd	xmm0, qword ptr [rdx + 8*rdi]   # xmm0 = mem[0],zero
	vmovsd	xmm2, qword ptr [r15 + 8*rdi]   # xmm2 = mem[0],zero
	lea	r8, [rdi + 1]
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm3, xmm2, xmm0        # xmm3 = (xmm2 * xmm0) + xmm3
	vfmadd231sd	xmm7, xmm2, xmm2        # xmm7 = (xmm2 * xmm2) + xmm7
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_16
	jmp	.LBB0_32
	.p2align	4
.LBB0_62:                               # %L522
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rsp + 40]       # 8-byte Reload
	cmp	rax, qword ptr [rsp + 32]       # 8-byte Folded Reload
	je	.LBB0_63
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r11, qword ptr [rbx + 16]
	jmp	.LBB0_4
.LBB0_63:
	mov	rcx, qword ptr [rsp + 24]       # 8-byte Reload
.LBB0_64:                               # %L533
	mov	rax, qword ptr [rsp + 8]
	mov	qword ptr [rcx], rax
	vmovapd	xmm0, xmm14
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_65:                               # %L47
	mov	qword ptr [rsp + 64], rsi
	mov	qword ptr [rsp + 16], rdi
	movabs	rax, offset j_throw_boundserror_2129
	lea	rsi, [rsp + 64]
	vzeroupper
	call	rax
.LBB0_66:                               # %L307
	mov	qword ptr [rsp + 72], rsi
	movabs	rax, offset j_throw_boundserror_2129
	lea	rsi, [rsp + 72]
	mov	rdi, rbx
	vzeroupper
	call	rax
.LBB0_67:                               # %L343
	movabs	rdi, offset ".Ljl_sym#sqrt#2134.jit"
	movabs	rax, offset j_throw_complex_domainerror_2133
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_70:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#2134.jit"
	movabs	rax, offset j_throw_complex_domainerror_2133
	vmovapd	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_71:                               # %L493
	movabs	rdi, offset ".Ljl_sym#sqrt#2134.jit"
	movabs	rax, offset j_throw_complex_domainerror_2133
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_69:                               # %L479
	movabs	rdi, offset ".Ljl_sym#sqrt#2134.jit"
	movabs	rax, offset j_throw_complex_domainerror_2133
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_68:                               # %L380
	mov	qword ptr [rsp + 88], rsi
	mov	qword ptr [rsp + 80], r10
	mov	qword ptr [rsp + 16], rdi
	movabs	rax, offset j_throw_boundserror_2136
	lea	rsi, [rsp + 80]
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_2126, .Lfunc_end0-julia_pass_2126
                                        # -- End function
	.type	".L+Core.Float64#2128",@object  # @"+Core.Float64#2128"
	.section	.lrodata,"al",@progbits
	.p2align	3, 0x0
".L+Core.Float64#2128":
	.quad	".L+Core.Float64#2128.jit"
	.size	".L+Core.Float64#2128", 8

.set ".Ljl_sym#sqrt#2134.jit", 131248270530416
	.size	".Ljl_sym#sqrt#2134.jit", 8
.set ".L+Core.Float64#2128.jit", 131248414322624
	.size	".L+Core.Float64#2128.jit", 8
	.section	".note.GNU-stack","",@progbits
