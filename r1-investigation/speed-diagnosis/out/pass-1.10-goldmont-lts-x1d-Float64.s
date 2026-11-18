	.text
	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_pass_1061
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5
.LCPI0_1:
	.quad	0x0000000000000000              # double 0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.text
	.globl	julia_pass_1061
	.p2align	4, 0x90
	.type	julia_pass_1061,@function
julia_pass_1061:                        # @julia_pass_1061
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 184
	vxorpd	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	vmovapd	xmmword ptr [rbp - 96], xmm0
	mov	qword ptr [rbp - 80], 0
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 96], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 88], rax
	lea	rax, [rbp - 96]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 128], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r11, qword ptr [rsi + 8]
	mov	r15, rsi
	test	r11, r11
	je	.LBB0_3
# %bb.4:                                # %L17.preheader479
	movabs	rdx, offset .LCPI0_0
	mov	qword ptr [rbp - 120], rcx      # 8-byte Spill
	movabs	rcx, offset .LCPI0_1
	mov	r12, qword ptr [rdi]
	mov	rbx, rdi
	vxorpd	xmm15, xmm15, xmm15
	mov	eax, 1
	vxorpd	xmm14, xmm14, xmm14
	mov	qword ptr [rbp - 64], rdi       # 8-byte Spill
	vbroadcastsd	ymm0, qword ptr [rdx]
	vmovapd	ymm1, ymmword ptr [rcx]
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vmovupd	ymmword ptr [rbp - 192], ymm1   # 32-byte Spill
	vmovupd	ymmword ptr [rbp - 224], ymm0   # 32-byte Spill
	.p2align	4, 0x90
.LBB0_6:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_8 Depth 2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_27 Depth 3
                                        #       Child Loop BB0_30 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	test	r11, r11
	mov	qword ptr [rbp - 136], rax      # 8-byte Spill
	je	.LBB0_60
# %bb.7:                                # %L31.preheader
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_58:                               # %L289
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, rbx
	mov	rsi, r14
	movabs	rax, offset j__sqrt_cold_1067
	mov	qword ptr [rbp - 144], r14      # 8-byte Spill
	mov	r14, r13
	mov	qword ptr [rbp - 80], r12
	mov	r13, r12
	mov	r12, rbx
	mov	rbx, r15
	vmovsd	qword ptr [rbp - 152], xmm14    # 8-byte Spill
	mov	r15, r11
	vzeroupper
	call	rax
	mov	r11, r15
	mov	r15, rbx
	mov	rbx, r12
	mov	r12, r13
	mov	r13, r14
	mov	r14, qword ptr [rbp - 144]      # 8-byte Reload
	vmovsd	xmm14, qword ptr [rbp - 152]    # 8-byte Reload
                                        # xmm14 = mem[0],zero
	vxorpd	xmm15, xmm15, xmm15
	vmovapd	xmm2, xmm0
.LBB0_59:                               # %L293
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm14, xmm14, xmm2
	add	r13, 8
	cmp	r14, r11
	lea	r14, [r14 + 1]
	je	.LBB0_60
.LBB0_8:                                # %L31
                                        #   Parent Loop BB0_6 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_27 Depth 3
                                        #       Child Loop BB0_30 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r10, [r14 - 1]
	cmp	r10, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rdi]
	mov	rsi, qword ptr [r12]
	vmovsd	xmm1, qword ptr [rax + 8*r14 - 8] # xmm1 = mem[0],zero
	mov	rax, qword ptr [r12 + 24]
	vucomisd	xmm1, xmm1
	mov	rcx, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.22:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_23
# %bb.24:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_26
# %bb.25:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	xor	edi, edi
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_23:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_26:                               # %vector.ph379
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, rcx
	movabs	rax, 9223372036854775800
	vmovupd	ymm3, ymmword ptr [rbp - 192]   # 32-byte Reload
	vmovupd	ymm4, ymmword ptr [rbp - 224]   # 32-byte Reload
	xor	ebx, ebx
	and	rdi, rax
	mov	rax, r8
	imul	rax, r13
	vmovapd	ymm0, ymm3
	vmovapd	ymm2, ymm4
	add	rax, rdx
	add	rax, 32
	.p2align	4, 0x90
.LBB0_27:                               # %vector.body384
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm5, ymmword ptr [rsi + 8*rbx]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rbx + 32]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [rax + 8*rbx - 32] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rax + 8*rbx] # ymm2 = (ymm6 * mem) + ymm2
	add	rbx, 8
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rdi, rbx
	jne	.LBB0_27
# %bb.28:                               # %middle.block376
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm3, ymm4, ymm3
	vaddpd	ymm0, ymm2, ymm0
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	cmp	rcx, rdi
	vextractf128	xmm2, ymm3, 1
	vaddpd	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddsd	xmm3, xmm2, xmm3
	vaddsd	xmm7, xmm0, xmm4
	je	.LBB0_31
.LBB0_29:                               # %scalar.ph377
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_30:                               # %L96
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [rsi + 8*rdi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm7, xmm0, qword ptr [rdx + 8*rdi] # xmm7 = (xmm0 * mem) + xmm7
	add	rdi, 1
	vfmadd231sd	xmm3, xmm0, xmm0        # xmm3 = (xmm0 * xmm0) + xmm3
	cmp	rcx, rdi
	jne	.LBB0_30
.LBB0_31:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=2
	cmp	r10, qword ptr [r15 + 8]
	jae	.LBB0_32
# %bb.66:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubsd	xmm0, xmm1, xmm1
	mov	rax, qword ptr [r15]
	vucomisd	xmm0, xmm0
	vmovsd	xmm0, qword ptr [rax + 8*r14 - 8] # xmm0 = mem[0],zero
	jp	.LBB0_58
# %bb.67:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, qword ptr [rbx]
	movabs	rax, offset .LCPI0_2
	mov	rdx, qword ptr [rsi + 24]
	mov	rcx, qword ptr [rdx + 8]
	vxorps	xmm10, xmm10, xmm10
	vcvtsi2sd	xmm2, xmm10, rcx
	vmulsd	xmm2, xmm2, qword ptr [rax]
	vucomisd	xmm1, xmm2
	jb	.LBB0_58
# %bb.68:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubsd	xmm4, xmm3, xmm3
	vucomisd	xmm4, xmm4
	jp	.LBB0_58
# %bb.69:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm3, xmm2
	jb	.LBB0_58
# %bb.35:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm15, xmm1
	ja	.LBB0_70
# %bb.36:                               # %L152
                                        #   in Loop: Header=BB0_8 Depth=2
	vsqrtsd	xmm4, xmm1, xmm1
	vmovsd	xmm5, qword ptr [rbx + 8]       # xmm5 = mem[0],zero
	vxorpd	xmm2, xmm2, xmm2
	vucomisd	xmm5, xmm4
	jae	.LBB0_59
# %bb.37:                               # %L157
                                        #   in Loop: Header=BB0_8 Depth=2
	vdivsd	xmm6, xmm7, xmm1
	movabs	rax, offset .LCPI0_3
	vmulsd	xmm2, xmm3, qword ptr [rax]
	vmulsd	xmm1, xmm7, xmm6
	vsubsd	xmm1, xmm3, xmm1
	vucomisd	xmm2, xmm1
	jbe	.LBB0_50
# %bb.38:                               # %L163
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rsi]
	cmp	r10, qword ptr [rdi + 32]
	mov	rax, qword ptr [rdi + 24]
	mov	qword ptr [rbp - 48], rax       # 8-byte Spill
	jae	.LBB0_71
# %bb.39:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_40
# %bb.41:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rdx]
	mov	rdx, qword ptr [rdi]
	cmp	rcx, 16
	jae	.LBB0_46
# %bb.42:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	esi, esi
	jmp	.LBB0_43
.LBB0_40:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_51
.LBB0_46:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	movabs	rdi, offset .LCPI0_0
	movabs	rbx, offset .LCPI0_1
	movabs	rsi, 9223372036854775800
	vbroadcastsd	ymm2, xmm6
	vbroadcastsd	ymm1, qword ptr [rdi]
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	vmovapd	ymm3, ymmword ptr [rbx]
	add	rsi, -8
	xor	ebx, ebx
	and	rsi, rcx
	imul	rdi, r13
	vmovapd	ymm7, ymm1
	vmovapd	ymm8, ymm1
	add	rdi, rdx
	add	rdi, 96
	.p2align	4, 0x90
.LBB0_47:                               # %vector.body
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulpd	ymm9, ymm2, ymmword ptr [rdi + 8*rbx - 96]
	vmulpd	ymm10, ymm2, ymmword ptr [rdi + 8*rbx - 64]
	vmulpd	ymm11, ymm2, ymmword ptr [rdi + 8*rbx - 32]
	vmovupd	ymm13, ymmword ptr [rax + 8*rbx]
	vmulpd	ymm12, ymm2, ymmword ptr [rdi + 8*rbx]
	vsubpd	ymm9, ymm13, ymm9
	vmovupd	ymm13, ymmword ptr [rax + 8*rbx + 32]
	vsubpd	ymm10, ymm13, ymm10
	vmovupd	ymm13, ymmword ptr [rax + 8*rbx + 64]
	vfmadd231pd	ymm3, ymm9, ymm9        # ymm3 = (ymm9 * ymm9) + ymm3
	vsubpd	ymm11, ymm13, ymm11
	vmovupd	ymm13, ymmword ptr [rax + 8*rbx + 96]
	add	rbx, 16
	vfmadd231pd	ymm1, ymm10, ymm10      # ymm1 = (ymm10 * ymm10) + ymm1
	cmp	rsi, rbx
	vsubpd	ymm12, ymm13, ymm12
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	jne	.LBB0_47
# %bb.48:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm1, ymm1, ymm3
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	cmp	rcx, rsi
	vaddpd	ymm1, ymm7, ymm1
	vaddpd	ymm1, ymm8, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddsd	xmm1, xmm1, xmm2
	jne	.LBB0_43
# %bb.49:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_50
.LBB0_43:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdi, r13
	add	rdx, rdi
	.p2align	4, 0x90
.LBB0_44:                               # %L208
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulsd	xmm2, xmm6, qword ptr [rdx + 8*rsi]
	vmovsd	xmm3, qword ptr [rax + 8*rsi]   # xmm3 = mem[0],zero
	add	rsi, 1
	cmp	rcx, rsi
	vsubsd	xmm2, xmm3, xmm2
	vfmadd231sd	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	jne	.LBB0_44
# %bb.45:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
.LBB0_50:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm15, xmm1
	ja	.LBB0_72
.LBB0_51:                               # %L252
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubsd	xmm2, xmm4, xmm5
	vucomisd	xmm15, xmm2
	ja	.LBB0_73
# %bb.52:                               # %L259
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm3, xmm4, xmm5
	vucomisd	xmm15, xmm3
	ja	.LBB0_74
# %bb.53:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vsqrtsd	xmm2, xmm2, xmm2
	vsqrtsd	xmm3, xmm3, xmm3
	vsqrtsd	xmm1, xmm1, xmm1
	vmulsd	xmm2, xmm2, xmm3
	vdivsd	xmm3, xmm5, xmm4
	vaddsd	xmm4, xmm6, xmm0
	vdivsd	xmm1, xmm1, xmm2
	vmulsd	xmm3, xmm3, xmm1
	vxorpd	xmm1, xmm1, xmm1
	vsubsd	xmm0, xmm4, xmm3
	vmovq	rax, xmm0
	vmovapd	xmm2, xmm0
	test	rax, rax
	jns	.LBB0_55
# %bb.54:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm2, xmm2, xmm2
.LBB0_55:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm3, xmm4, xmm3
	vmovq	rax, xmm3
	test	rax, rax
	jns	.LBB0_57
# %bb.56:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovapd	xmm1, xmm3
.LBB0_57:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vcmpordsd	xmm4, xmm0, xmm0
	vcmpordsd	xmm5, xmm3, xmm3
	vblendvpd	xmm0, xmm0, xmm2, xmm4
	vblendvpd	xmm1, xmm3, xmm1, xmm5
	vaddsd	xmm2, xmm0, xmm1
	jmp	.LBB0_59
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	r9, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_20
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_31
.LBB0_17:                               # %vector.ph402
                                        #   in Loop: Header=BB0_8 Depth=2
	movabs	rax, offset .LCPI0_0
	mov	rdi, rcx
	xor	edx, edx
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, 9223372036854775800
	and	rdi, rax
	mov	rax, r8
	imul	rax, r13
	vmovapd	ymm3, ymm0
	vmovapd	ymm5, ymm0
	lea	rbx, [r9 + rax + 32]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	vmovapd	ymm2, ymm1
	vmovapd	ymm4, ymm1
.LBB0_18:                               # %vector.body407
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm6, ymmword ptr [rbx + 8*rdx - 32]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rdx]
	vmovupd	ymm7, ymmword ptr [rbx + 8*rdx]
	vmovupd	ymm9, ymmword ptr [rsi + 8*rdx + 32]
	add	rdx, 8
	cmp	rdi, rdx
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm7        # ymm3 = (ymm9 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
	jne	.LBB0_18
# %bb.19:                               # %middle.block399
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm4, ymm5, ymm4
	vaddpd	ymm0, ymm0, ymm1
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	cmp	rcx, rdi
	vextractf128	xmm1, ymm4, 1
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm1, xmm4, xmm1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm3, xmm1, xmm3
	vpermilpd	xmm1, xmm2, 1           # xmm1 = xmm2[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddsd	xmm7, xmm2, xmm1
	vaddsd	xmm1, xmm0, xmm4
	je	.LBB0_31
.LBB0_20:                               # %scalar.ph400
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	r9, r8
.LBB0_21:                               # %L54
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [r9 + 8*rdi]    # xmm0 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	add	rdi, 1
	cmp	rcx, rdi
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm7, xmm2, xmm0        # xmm7 = (xmm2 * xmm0) + xmm7
	vfmadd231sd	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	jne	.LBB0_21
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_60:                               # %L305
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	rax, qword ptr [rbp - 136]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 128]      # 8-byte Folded Reload
	je	.LBB0_61
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r11, qword ptr [r15 + 8]
	add	rax, 1
	jmp	.LBB0_6
.LBB0_61:
	mov	rcx, qword ptr [rbp - 120]      # 8-byte Reload
	mov	rdx, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_62
.LBB0_1:
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_63
.LBB0_3:
                                        # implicit-def: $rax
	vxorpd	xmm14, xmm14, xmm14
                                        # implicit-def: $rdx
                                        # kill: killed $rax
.LBB0_62:                               # %L316.loopexit
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 112], rax
	mov	qword ptr [rbp - 104], rdx
.LBB0_63:                               # %L316
	mov	rax, qword ptr [rbp - 88]
	vmovapd	xmm0, xmm14
	mov	qword ptr [rcx], rax
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_9:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_64
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_64:                               # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_32:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_65
.LBB0_34:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_34
.LBB0_65:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r15
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_70:                               # %L150
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_73:                               # %L257
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_74:                               # %L264
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_72:                               # %L250
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_71:                               # %L181
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	lea	rsi, [rbp - 112]
	mov	qword ptr [rbp - 80], rdi
	mov	qword ptr [rbp - 112], rax
	movabs	rax, offset j_throw_boundserror_1066
	mov	qword ptr [rbp - 104], r14
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1061, .Lfunc_end0-julia_pass_1061
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
