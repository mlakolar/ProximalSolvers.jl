	.file	"pass"
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0                          # -- Begin function julia_pass_3537
.LCPI0_0:
	.long	0x80000000                      # float -0
.LCPI0_2:
	.long	0x0c000000                      # float 9.86076131E-32
.LCPI0_3:
	.long	0x3d800000                      # float 0.0625
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5, 0x0
.LCPI0_1:
	.long	0x00000000                      # float 0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_4:
	.zero	4
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.ltext,"axl",@progbits
	.globl	julia_pass_3537
	.p2align	4
	.type	julia_pass_3537,@function
julia_pass_3537:                        # @julia_pass_3537
; Function Signature: pass(typeof(M_x1d.ProximalSolvers._column_dot_rsqr), typeof(M_x1d.ProximalSolvers._sqrt_minimizer), M_x1d.ProximalSolvers.SqrtLSModel{Float32, M_x1d.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
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
	sub	rsp, 136
	vxorps	xmm0, xmm0, xmm0
	vmovaps	xmmword ptr [rbp - 96], xmm0
	mov	qword ptr [rbp - 80], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 96], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 88], rax
	lea	rax, [rbp - 96]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorps	xmm14, xmm14, xmm14
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 112], rax      # 8-byte Spill
	jle	.LBB0_71
# %bb.1:                                # %L17.preheader
	mov	rbx, rsi
	mov	r11, qword ptr [rsi + 16]
	test	r11, r11
	jle	.LBB0_71
# %bb.2:                                # %L17.preheader3
	mov	r14, rdi
	mov	qword ptr [rbp - 104], rcx      # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorps	xmm15, xmm15, xmm15
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastss	xmm0, dword ptr [rcx]
	vmovaps	xmmword ptr [rbp - 160], xmm0   # 16-byte Spill
	mov	qword ptr [rbp - 56], rbx       # 8-byte Spill
	.p2align	4
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_35 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_55 Depth 3
                                        #       Child Loop BB0_59 Depth 3
                                        #       Child Loop BB0_62 Depth 3
	mov	qword ptr [rbp - 120], rax      # 8-byte Spill
	test	r11, r11
	jle	.LBB0_69
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15d, 1
	xor	r13d, r13d
	jmp	.LBB0_6
	.p2align	4
.LBB0_67:                               # %L506
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 80], r12
	mov	rdi, r14
	mov	rsi, r15
	vmovss	dword ptr [rbp - 48], xmm14     # 4-byte Spill
	mov	rbx, r14
	mov	r14, r11
	movabs	rax, offset j__sqrt_cold_3547
	vzeroupper
	call	rax
	mov	r11, r14
	mov	r14, rbx
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm15, xmm15, xmm15
	vmovss	xmm14, dword ptr [rbp - 48]     # 4-byte Reload
                                        # xmm14 = mem[0],zero,zero,zero
	vmovaps	xmm2, xmm0
.LBB0_68:                               # %L510
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm14, xmm14, xmm2
	lea	rax, [r15 + 1]
	add	r13, 4
	cmp	r15, r11
	mov	r15, rax
	je	.LBB0_69
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_35 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_55 Depth 3
                                        #       Child Loop BB0_59 Depth 3
                                        #       Child Loop BB0_62 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	rax, [r15 - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_72
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r12]
	mov	rsi, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovss	xmm1, dword ptr [rcx + 4*r15 - 4] # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm1
	mov	rcx, qword ptr [rsi + 16]
	jp	.LBB0_8
# %bb.24:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_25
# %bb.26:                               # %iter.check561
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_28
# %bb.27:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_37
	.p2align	4
.LBB0_25:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_39
	.p2align	4
.LBB0_28:                               # %vector.main.loop.iter.check563
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 32
	jae	.LBB0_30
# %bb.29:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_34
.LBB0_30:                               # %vector.ph564
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -28
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm3, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm6, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm7, ymm3
	vmovaps	ymm8, ymm3
	vmovaps	ymm0, ymm6
	vmovaps	ymm2, ymm3
	vmovaps	ymm4, ymm3
	vmovaps	ymm5, ymm3
	.p2align	4
.LBB0_31:                               # %vector.body567
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm9, ymmword ptr [rsi + 4*r10]
	vmovups	ymm10, ymmword ptr [rsi + 4*r10 + 32]
	vmovups	ymm11, ymmword ptr [rsi + 4*r10 + 64]
	vmovups	ymm12, ymmword ptr [rsi + 4*r10 + 96]
	vfmadd231ps	ymm6, ymm9, ymmword ptr [r9 + 4*r10 - 96] # ymm6 = (ymm9 * mem) + ymm6
	vfmadd231ps	ymm3, ymm10, ymmword ptr [r9 + 4*r10 - 64] # ymm3 = (ymm10 * mem) + ymm3
	vfmadd231ps	ymm7, ymm11, ymmword ptr [r9 + 4*r10 - 32] # ymm7 = (ymm11 * mem) + ymm7
	vfmadd231ps	ymm8, ymm12, ymmword ptr [r9 + 4*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231ps	ymm0, ymm9, ymm9        # ymm0 = (ymm9 * ymm9) + ymm0
	vfmadd231ps	ymm2, ymm10, ymm10      # ymm2 = (ymm10 * ymm10) + ymm2
	vfmadd231ps	ymm4, ymm11, ymm11      # ymm4 = (ymm11 * ymm11) + ymm4
	vfmadd231ps	ymm5, ymm12, ymm12      # ymm5 = (ymm12 * ymm12) + ymm5
	add	r10, 32
	cmp	rdi, r10
	jne	.LBB0_31
# %bb.32:                               # %middle.block558
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm3, ymm3, ymm6
	vaddps	ymm3, ymm7, ymm3
	vaddps	ymm3, ymm8, ymm3
	vextractf128	xmm6, ymm3, 1
	vaddps	xmm3, xmm3, xmm6
	vshufpd	xmm6, xmm3, xmm3, 1             # xmm6 = xmm3[1,0]
	vaddps	xmm3, xmm3, xmm6
	vmovshdup	xmm6, xmm3              # xmm6 = xmm3[1,1,3,3]
	vaddss	xmm3, xmm3, xmm6
	vaddps	ymm0, ymm2, ymm0
	vaddps	ymm0, ymm4, ymm0
	vaddps	ymm0, ymm5, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm2
	cmp	rcx, rdi
	je	.LBB0_39
# %bb.33:                               # %vec.epilog.iter.check599
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 28
	je	.LBB0_37
.LBB0_34:                               # %vec.epilog.ph598
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm0, xmmword ptr [rbp - 160]   # 16-byte Reload
	vblendps	xmm2, xmm0, xmm3, 1             # xmm2 = xmm3[0],xmm0[1,2,3]
	vblendps	xmm0, xmm0, xmm4, 1             # xmm0 = xmm4[0],xmm0[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
	.p2align	4
.LBB0_35:                               # %vec.epilog.vector.body604
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm2, xmm3, xmmword ptr [r10 + 4*r9] # xmm2 = (xmm3 * mem) + xmm2
	vfmadd231ps	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_35
# %bb.36:                               # %vec.epilog.middle.block596
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm2
	cmp	rcx, rdi
	je	.LBB0_39
.LBB0_37:                               # %L190.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4
.LBB0_38:                               # %L190
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm3, xmm0, dword ptr [rdx + 4*rdi] # xmm3 = (xmm0 * mem) + xmm3
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm4, xmm0, xmm0        # xmm4 = (xmm0 * xmm0) + xmm4
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_38
.LBB0_39:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [rbx + 16]
	jae	.LBB0_73
# %bb.40:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rbx]
	vmovss	xmm0, dword ptr [rcx + 4*r15 - 4] # xmm0 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm1, xmm1
	vucomiss	xmm2, xmm2
	jp	.LBB0_67
# %bb.41:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [r14]
	mov	rdx, qword ptr [rsi + 24]
	mov	rcx, qword ptr [rdx + 16]
	vxorps	xmm13, xmm13, xmm13
	vcvtsi2ss	xmm2, xmm13, rcx
	movabs	rdi, offset .LCPI0_2
	vmulss	xmm2, xmm2, dword ptr [rdi]
	vucomiss	xmm1, xmm2
	jb	.LBB0_67
# %bb.42:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm5, xmm4, xmm4
	vucomiss	xmm5, xmm5
	jp	.LBB0_67
# %bb.43:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm4, xmm2
	jb	.LBB0_67
# %bb.44:                               # %L341
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm15, xmm1
	ja	.LBB0_74
# %bb.45:                               # %L345
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	xmm5, dword ptr [r14 + 8]       # xmm5 = mem[0],zero,zero,zero
	vsqrtss	xmm6, xmm1, xmm1
	vxorps	xmm2, xmm2, xmm2
	vucomiss	xmm5, xmm6
	jae	.LBB0_68
# %bb.46:                               # %L350
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm7, xmm3, xmm1
	vmulss	xmm1, xmm3, xmm7
	vsubss	xmm1, xmm4, xmm1
	movabs	rdi, offset .LCPI0_3
	vmulss	xmm2, xmm4, dword ptr [rdi]
	vucomiss	xmm2, xmm1
	jbe	.LBB0_63
# %bb.47:                               # %L356
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, qword ptr [rsi]
	mov	rsi, qword ptr [rdi + 16]
	cmp	rax, qword ptr [rdi + 24]
	jae	.LBB0_75
# %bb.48:                               # %L383
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_49
# %bb.50:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rdx]
	mov	rdx, qword ptr [rdi]
	cmp	rcx, 4
	jae	.LBB0_52
# %bb.51:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	jmp	.LBB0_61
.LBB0_49:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_64
.LBB0_52:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 32
	jae	.LBB0_54
# %bb.53:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	jmp	.LBB0_58
.LBB0_54:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -28
	and	rdi, rcx
	vbroadcastss	ymm1, xmm7
	mov	r8, rsi
	imul	r8, r13
	add	r8, rdx
	add	r8, 96
	movabs	r9, offset .LCPI0_0
	vbroadcastss	ymm2, dword ptr [r9]
	movabs	r9, offset .LCPI0_1
	vmovaps	ymm3, ymmword ptr [r9]
	xor	r9d, r9d
	vmovaps	ymm4, ymm2
	vmovaps	ymm8, ymm2
	.p2align	4
.LBB0_55:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm9, ymmword ptr [rax + 4*r9]
	vmovups	ymm10, ymmword ptr [rax + 4*r9 + 32]
	vmovups	ymm11, ymmword ptr [rax + 4*r9 + 64]
	vmovups	ymm12, ymmword ptr [rax + 4*r9 + 96]
	vmulps	ymm13, ymm1, ymmword ptr [r8 + 4*r9 - 96]
	vsubps	ymm9, ymm9, ymm13
	vmulps	ymm13, ymm1, ymmword ptr [r8 + 4*r9 - 64]
	vsubps	ymm10, ymm10, ymm13
	vmulps	ymm13, ymm1, ymmword ptr [r8 + 4*r9 - 32]
	vsubps	ymm11, ymm11, ymm13
	vmulps	ymm13, ymm1, ymmword ptr [r8 + 4*r9]
	vsubps	ymm12, ymm12, ymm13
	vfmadd231ps	ymm3, ymm9, ymm9        # ymm3 = (ymm9 * ymm9) + ymm3
	vfmadd231ps	ymm2, ymm10, ymm10      # ymm2 = (ymm10 * ymm10) + ymm2
	vfmadd231ps	ymm4, ymm11, ymm11      # ymm4 = (ymm11 * ymm11) + ymm4
	vfmadd231ps	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	add	r9, 32
	cmp	rdi, r9
	jne	.LBB0_55
# %bb.56:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm1, ymm2, ymm3
	vaddps	ymm1, ymm4, ymm1
	vaddps	ymm1, ymm8, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_63
# %bb.57:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 28
	je	.LBB0_61
.LBB0_58:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, rdi
	mov	rdi, rcx
	movabs	r9, 9223372036854775804
	and	rdi, r9
	movabs	r9, offset .LCPI0_4
	vblendps	xmm1, xmm1, xmmword ptr [r9], 14 # xmm1 = xmm1[0],mem[1,2,3]
	vbroadcastss	xmm2, xmm7
	mov	r9, rsi
	imul	r9, r13
	add	r9, rdx
	.p2align	4
.LBB0_59:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [rax + 4*r8]
	vmulps	xmm4, xmm2, xmmword ptr [r9 + 4*r8]
	vsubps	xmm3, xmm3, xmm4
	vfmadd231ps	xmm1, xmm3, xmm3        # xmm1 = (xmm3 * xmm3) + xmm1
	add	r8, 4
	cmp	rdi, r8
	jne	.LBB0_59
# %bb.60:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_63
.LBB0_61:                               # %L406.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	rsi, r13
	add	rdx, rsi
	.p2align	4
.LBB0_62:                               # %L406
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm2, dword ptr [rax + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	vmulss	xmm3, xmm7, dword ptr [rdx + 4*rdi]
	lea	rsi, [rdi + 1]
	vsubss	xmm2, xmm2, xmm3
	vfmadd231ss	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	mov	rdi, rsi
	cmp	rcx, rsi
	jne	.LBB0_62
.LBB0_63:                               # %L474
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm15, xmm1
	ja	.LBB0_76
.LBB0_64:                               # %L481
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm2, xmm6, xmm5
	vucomiss	xmm15, xmm2
	ja	.LBB0_77
# %bb.65:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm3, xmm6, xmm5
	vucomiss	xmm15, xmm3
	ja	.LBB0_78
# %bb.66:                               # %L495
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm0, xmm7, xmm0
	vdivss	xmm4, xmm5, xmm6
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	vsqrtss	xmm3, xmm3, xmm3
	vmulss	xmm2, xmm2, xmm3
	vdivss	xmm1, xmm1, xmm2
	vmulss	xmm1, xmm4, xmm1
	vsubss	xmm2, xmm0, xmm1
	vcmpunordss	xmm3, xmm2, xmm2
	vmaxss	xmm4, xmm2, xmm15
	vblendvps	xmm2, xmm4, xmm2, xmm3
	vaddss	xmm0, xmm0, xmm1
	vminss	xmm0, xmm15, xmm0
	vaddss	xmm2, xmm2, xmm0
	jmp	.LBB0_68
.LBB0_8:                                # %L58
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_9
# %bb.10:                               # %iter.check618
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_22
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_39
.LBB0_12:                               # %vector.main.loop.iter.check620
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r14       # 8-byte Spill
	mov	qword ptr [rbp - 48], r11       # 8-byte Spill
	vmovaps	xmm10, xmm14
	cmp	rcx, 16
	jae	.LBB0_14
# %bb.13:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_19
.LBB0_14:                               # %vector.ph621
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -12
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm1, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm5, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm3, ymm5
	vmovaps	ymm4, ymm1
	vmovaps	ymm0, ymm5
	vmovaps	ymm2, ymm1
.LBB0_15:                               # %vector.body624
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm6, ymmword ptr [r9 + 4*r10 - 32]
	vmovups	ymm7, ymmword ptr [r9 + 4*r10]
	vmovups	ymm8, ymmword ptr [rsi + 4*r10]
	vmovups	ymm9, ymmword ptr [rsi + 4*r10 + 32]
	vfmadd231ps	ymm5, ymm6, ymm6        # ymm5 = (ymm6 * ymm6) + ymm5
	vfmadd231ps	ymm1, ymm7, ymm7        # ymm1 = (ymm7 * ymm7) + ymm1
	vfmadd231ps	ymm3, ymm8, ymm6        # ymm3 = (ymm8 * ymm6) + ymm3
	vfmadd231ps	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	vfmadd231ps	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_15
# %bb.16:                               # %middle.block615
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm1, ymm1, ymm5
	vextractf128	xmm5, ymm1, 1
	vaddps	xmm1, xmm1, xmm5
	vshufpd	xmm5, xmm1, xmm1, 1             # xmm5 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm5
	vmovshdup	xmm5, xmm1              # xmm5 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm5
	vaddps	ymm3, ymm4, ymm3
	vextractf128	xmm4, ymm3, 1
	vaddps	xmm3, xmm3, xmm4
	vshufpd	xmm4, xmm3, xmm3, 1             # xmm4 = xmm3[1,0]
	vaddps	xmm3, xmm3, xmm4
	vmovshdup	xmm4, xmm3              # xmm4 = xmm3[1,1,3,3]
	vaddss	xmm3, xmm3, xmm4
	vaddps	ymm0, ymm2, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm2
	cmp	rcx, rdi
	jne	.LBB0_18
# %bb.17:                               #   in Loop: Header=BB0_6 Depth=2
	vmovaps	xmm14, xmm10
	vxorps	xmm15, xmm15, xmm15
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r14, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_39
.LBB0_18:                               # %vec.epilog.iter.check648
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	vmovaps	xmm14, xmm10
	vxorps	xmm15, xmm15, xmm15
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r14, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_22
.LBB0_19:                               # %vec.epilog.ph647
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm0, xmmword ptr [rbp - 160]   # 16-byte Reload
	vblendps	xmm1, xmm0, xmm1, 1             # xmm1 = xmm1[0],xmm0[1,2,3]
	vblendps	xmm2, xmm0, xmm3, 1             # xmm2 = xmm3[0],xmm0[1,2,3]
	vblendps	xmm0, xmm0, xmm4, 1             # xmm0 = xmm4[0],xmm0[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
.LBB0_20:                               # %vec.epilog.vector.body653
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [r10 + 4*r9]
	vmovups	xmm4, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm1, xmm3, xmm3        # xmm1 = (xmm3 * xmm3) + xmm1
	vfmadd231ps	xmm2, xmm4, xmm3        # xmm2 = (xmm4 * xmm3) + xmm2
	vfmadd231ps	xmm0, xmm4, xmm4        # xmm0 = (xmm4 * xmm4) + xmm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_20
# %bb.21:                               # %vec.epilog.middle.block645
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm1, xmm1, 1             # xmm3 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm3
	vmovshdup	xmm3, xmm1              # xmm3 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	vshufpd	xmm2, xmm0, xmm0, 1             # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm2
	cmp	rcx, rdi
	vmovaps	xmm14, xmm10
	vxorps	xmm15, xmm15, xmm15
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r14, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_39
.LBB0_22:                               # %L71.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
.LBB0_23:                               # %L71
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rdx + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm3, xmm2, xmm0        # xmm3 = (xmm2 * xmm0) + xmm3
	vfmadd231ss	xmm4, xmm2, xmm2        # xmm4 = (xmm2 * xmm2) + xmm4
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_23
	jmp	.LBB0_39
	.p2align	4
.LBB0_69:                               # %L522
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 120]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 112]      # 8-byte Folded Reload
	je	.LBB0_70
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r11, qword ptr [rbx + 16]
	jmp	.LBB0_4
.LBB0_70:
	mov	rcx, qword ptr [rbp - 104]      # 8-byte Reload
.LBB0_71:                               # %L533
	mov	rax, qword ptr [rbp - 88]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm14
	add	rsp, 136
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_72:                               # %L47
	mov	qword ptr [rbp - 128], r15
	mov	qword ptr [rbp - 80], rdi
	movabs	rax, offset j_throw_boundserror_3539
	lea	rsi, [rbp - 128]
	vzeroupper
	call	rax
.LBB0_73:                               # %L307
	mov	qword ptr [rbp - 136], r15
	movabs	rax, offset j_throw_boundserror_3539
	lea	rsi, [rbp - 136]
	mov	rdi, rbx
	vzeroupper
	call	rax
.LBB0_74:                               # %L343
	movabs	rdi, offset ".Ljl_sym#sqrt#3544.jit"
	movabs	rax, offset j_throw_complex_domainerror_3543
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_77:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#3544.jit"
	movabs	rax, offset j_throw_complex_domainerror_3543
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_78:                               # %L493
	movabs	rdi, offset ".Ljl_sym#sqrt#3544.jit"
	movabs	rax, offset j_throw_complex_domainerror_3543
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_76:                               # %L479
	movabs	rdi, offset ".Ljl_sym#sqrt#3544.jit"
	movabs	rax, offset j_throw_complex_domainerror_3543
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_75:                               # %L380
	mov	qword ptr [rbp - 168], r15
	mov	qword ptr [rbp - 176], rsi
	mov	qword ptr [rbp - 80], rdi
	movabs	rax, offset j_throw_boundserror_3546
	lea	rsi, [rbp - 176]
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_3537, .Lfunc_end0-julia_pass_3537
                                        # -- End function
.set ".Ljl_sym#sqrt#3544.jit", 131248270530416
	.size	".Ljl_sym#sqrt#3544.jit", 8
	.section	".note.GNU-stack","",@progbits
