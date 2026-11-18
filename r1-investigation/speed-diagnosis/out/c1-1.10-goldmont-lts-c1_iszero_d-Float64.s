	.text
	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_pass_1072
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
.LCPI0_4:
	.quad	0x7fefffffffffffff              # double 1.7976931348623157E+308
.LCPI0_5:
	.quad	0x0010000000000000              # double 2.2250738585072014E-308
.LCPI0_7:
	.quad	0x3ff0000000000000              # double 1
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5
.LCPI0_1:
	.quad	0x0000000000000000              # double 0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4
.LCPI0_6:
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.text
	.globl	julia_pass_1072
	.p2align	4, 0x90
	.type	julia_pass_1072,@function
julia_pass_1072:                        # @julia_pass_1072
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 168
	vxorpd	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	vxorpd	xmm7, xmm7, xmm7
	vmovapd	xmmword ptr [rbp - 80], xmm0
	mov	qword ptr [rbp - 64], 0
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 80], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 72], rax
	lea	rax, [rbp - 80]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 96], rax       # 8-byte Spill
	jle	.LBB0_68
# %bb.1:                                # %L17.preheader
	mov	rax, qword ptr [rsi + 8]
	mov	r11, rsi
	test	rax, rax
	je	.LBB0_68
# %bb.2:                                # %L17.preheader377
	movabs	rdx, offset .LCPI0_0
	mov	qword ptr [rbp - 88], rcx       # 8-byte Spill
	movabs	rcx, offset .LCPI0_1
	mov	r12, qword ptr [rdi]
	mov	r15, rax
	mov	rbx, rdi
	mov	eax, 1
	vxorpd	xmm7, xmm7, xmm7
	mov	qword ptr [rbp - 56], rdi       # 8-byte Spill
	mov	qword ptr [rbp - 48], r11       # 8-byte Spill
	vbroadcastsd	ymm0, qword ptr [rdx]
	vmovapd	ymm1, ymmword ptr [rcx]
	vmovupd	ymmword ptr [rbp - 176], ymm1   # 32-byte Spill
	vmovupd	ymmword ptr [rbp - 208], ymm0   # 32-byte Spill
	.p2align	4, 0x90
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_19 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_41 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	test	r15, r15
	mov	qword ptr [rbp - 120], rax      # 8-byte Spill
	je	.LBB0_66
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	jmp	.LBB0_6
	.p2align	4, 0x90
.LBB0_64:                               # %L322
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rbx
	vmovapd	xmm0, xmm2
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1078
	mov	qword ptr [rbp - 64], r12
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	vmovapd	xmm3, xmm0
.LBB0_65:                               # %L324
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovsd	xmm7, qword ptr [rbp - 128]     # 8-byte Reload
                                        # xmm7 = mem[0],zero
	add	r13, 8
	cmp	r14, r15
	lea	r14, [r14 + 1]
	vaddsd	xmm7, xmm7, xmm3
	je	.LBB0_66
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_19 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_41 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r10, [r14 - 1]
	cmp	r10, qword ptr [rdi + 8]
	jae	.LBB0_7
# %bb.10:                               # %idxend
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rdi]
	mov	rsi, qword ptr [r12]
	vmovsd	xmm0, qword ptr [rax + 8*r14 - 8] # xmm0 = mem[0],zero
	mov	rax, qword ptr [r12 + 24]
	vucomisd	xmm0, xmm0
	mov	rcx, qword ptr [rax + 8]
	jp	.LBB0_11
# %bb.20:                               # %L83
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	je	.LBB0_21
# %bb.22:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_24
# %bb.23:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm6, xmm6, xmm6
	xor	edi, edi
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_27
	.p2align	4, 0x90
.LBB0_21:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_24:                               # %vector.ph283
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	rax, 9223372036854775800
	vmovupd	ymm3, ymmword ptr [rbp - 176]   # 32-byte Reload
	vmovupd	ymm4, ymmword ptr [rbp - 208]   # 32-byte Reload
	xor	ebx, ebx
	and	rdi, rax
	mov	rax, r8
	imul	rax, r13
	vmovapd	ymm1, ymm3
	vmovapd	ymm2, ymm4
	add	rax, rdx
	add	rax, 32
	.p2align	4, 0x90
.LBB0_25:                               # %vector.body288
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm5, ymmword ptr [rsi + 8*rbx]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rbx + 32]
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rax + 8*rbx - 32] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rax + 8*rbx] # ymm2 = (ymm6 * mem) + ymm2
	add	rbx, 8
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rdi, rbx
	jne	.LBB0_25
# %bb.26:                               # %middle.block280
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm3, ymm4, ymm3
	vaddpd	ymm1, ymm2, ymm1
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	cmp	rcx, rdi
	vextractf128	xmm2, ymm3, 1
	vaddpd	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm1, 1
	vaddpd	xmm1, xmm1, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm5, xmm1, 1           # xmm5 = xmm1[1,0]
	vaddsd	xmm4, xmm2, xmm3
	vaddsd	xmm6, xmm1, xmm5
	je	.LBB0_29
.LBB0_27:                               # %scalar.ph281
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_28:                               # %L96
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [rsi + 8*rdi]   # xmm1 = mem[0],zero
	vfmadd231sd	xmm6, xmm1, qword ptr [rdx + 8*rdi] # xmm6 = (xmm1 * mem) + xmm6
	add	rdi, 1
	vfmadd231sd	xmm4, xmm1, xmm1        # xmm4 = (xmm1 * xmm1) + xmm4
	cmp	rcx, rdi
	jne	.LBB0_28
.LBB0_29:                               # %L124
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	r10, qword ptr [r11 + 8]
	jae	.LBB0_30
# %bb.71:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm1, xmm0, xmm0
	mov	rax, qword ptr [r11]
	vmovsd	qword ptr [rbp - 128], xmm7     # 8-byte Spill
	vucomisd	xmm1, xmm1
	vmovsd	xmm2, qword ptr [rax + 8*r14 - 8] # xmm2 = mem[0],zero
	jp	.LBB0_64
# %bb.72:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rbx]
	movabs	rsi, offset .LCPI0_2
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm15, xmm15, xmm15
	vcvtsi2sd	xmm1, xmm15, rax
	vmulsd	xmm7, xmm1, qword ptr [rsi]
	vucomisd	xmm0, xmm7
	jb	.LBB0_64
# %bb.73:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm1, xmm4, xmm4
	vucomisd	xmm1, xmm1
	jp	.LBB0_64
# %bb.74:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm4, xmm7
	jb	.LBB0_64
# %bb.33:                               # %L144
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	vucomisd	xmm1, xmm0
	ja	.LBB0_75
# %bb.34:                               # %L150
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtsd	xmm1, xmm0, xmm0
	vmovsd	xmm14, qword ptr [rbx + 8]      # xmm14 = mem[0],zero
	vxorpd	xmm3, xmm3, xmm3
	vucomisd	xmm14, xmm1
	jae	.LBB0_65
# %bb.35:                               # %L155
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm5, xmm6, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm3, xmm4, qword ptr [rsi]
	vmulsd	xmm0, xmm6, xmm5
	vsubsd	xmm0, xmm4, xmm0
	vucomisd	xmm3, xmm0
	jbe	.LBB0_48
# %bb.36:                               # %L162
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	je	.LBB0_37
# %bb.38:                               # %L176.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	cmp	rax, 16
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	jae	.LBB0_40
# %bb.39:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_43
.LBB0_37:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_45
.LBB0_40:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, offset .LCPI0_0
	movabs	rsi, 9223372036854775800
	vbroadcastsd	ymm3, xmm5
	vbroadcastsd	ymm0, qword ptr [rdi]
	mov	rdi, r8
	add	rsi, -8
	imul	rdi, r13
	and	rsi, rax
	vmovapd	ymm6, ymm0
	vmovapd	ymm8, ymm0
	lea	rbx, [rdx + rdi + 96]
	movabs	rdi, offset .LCPI0_1
	vmovapd	ymm4, ymmword ptr [rdi]
	xor	edi, edi
	.p2align	4, 0x90
.LBB0_41:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulpd	ymm9, ymm3, ymmword ptr [rbx + 8*rdi - 96]
	vmulpd	ymm10, ymm3, ymmword ptr [rbx + 8*rdi - 64]
	vmulpd	ymm11, ymm3, ymmword ptr [rbx + 8*rdi - 32]
	vmulpd	ymm12, ymm3, ymmword ptr [rbx + 8*rdi]
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdi]
	vmovupd	ymm15, ymmword ptr [rcx + 8*rdi + 96]
	vsubpd	ymm9, ymm13, ymm9
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdi + 32]
	vsubpd	ymm12, ymm15, ymm12
	vsubpd	ymm10, ymm13, ymm10
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdi + 64]
	add	rdi, 16
	vfmadd231pd	ymm4, ymm9, ymm9        # ymm4 = (ymm9 * ymm9) + ymm4
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	cmp	rsi, rdi
	vsubpd	ymm11, ymm13, ymm11
	vfmadd231pd	ymm0, ymm10, ymm10      # ymm0 = (ymm10 * ymm10) + ymm0
	vfmadd231pd	ymm6, ymm11, ymm11      # ymm6 = (ymm11 * ymm11) + ymm6
	jne	.LBB0_41
# %bb.42:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm0, ymm4
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	cmp	rax, rsi
	vaddpd	ymm0, ymm6, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm3
	je	.LBB0_45
.LBB0_43:                               # %scalar.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_44:                               # %L176
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulsd	xmm3, xmm5, qword ptr [rdx + 8*rsi]
	vmovsd	xmm4, qword ptr [rcx + 8*rsi]   # xmm4 = mem[0],zero
	add	rsi, 1
	cmp	rax, rsi
	vsubsd	xmm3, xmm4, xmm3
	vfmadd231sd	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	jne	.LBB0_44
.LBB0_45:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm0, xmm7
	jb	.LBB0_47
# %bb.46:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm3, xmm0, xmm0
	vucomisd	xmm3, xmm3
	jp	.LBB0_47
.LBB0_48:                               # %L210
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm8, xmm8, xmm8
	vucomisd	xmm8, xmm0
	ja	.LBB0_76
# %bb.49:                               # %L215
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm3, xmm1, xmm14
	vucomisd	xmm8, xmm3
	ja	.LBB0_77
# %bb.50:                               # %L222
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm4, xmm14, xmm1
	vucomisd	xmm8, xmm4
	ja	.LBB0_78
# %bb.51:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtsd	xmm6, xmm3, xmm3
	vsqrtsd	xmm4, xmm4, xmm4
	vsqrtsd	xmm3, xmm0, xmm0
	movabs	rdx, offset .LCPI0_5
	vaddsd	xmm9, xmm5, xmm2
	vmulsd	xmm0, xmm6, xmm4
	vucomisd	xmm3, xmm8
	vmovsd	xmm4, qword ptr [rdx]           # xmm4 = mem[0],zero
	setnp	cl
	sete	al
	vmulsd	xmm0, xmm1, xmm0
	vucomisd	xmm0, xmm4
	jb	.LBB0_63
# %bb.52:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm0, xmm3, xmm0
	movabs	rdx, offset .LCPI0_4
	and	al, cl
	vmovsd	xmm2, qword ptr [rdx]           # xmm2 = mem[0],zero
	vmulsd	xmm7, xmm14, xmm0
	vcmplepd	xmm5, xmm0, xmm2
	vcmplepd	xmm6, xmm4, xmm0
	vandpd	xmm5, xmm6, xmm5
	vmovd	ecx, xmm5
	vcmplepd	xmm2, xmm7, xmm2
	vcmplepd	xmm4, xmm4, xmm7
	vandpd	xmm2, xmm4, xmm2
	vmovd	edx, xmm2
	and	edx, ecx
	or	dl, al
	test	dl, 1
	je	.LBB0_63
# %bb.53:                               # %L253
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_5
	vucomisd	xmm7, qword ptr [rax]
	jb	.LBB0_56
# %bb.54:                               # %L253
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_4
	vmovsd	xmm1, qword ptr [rax]           # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm7
	jb	.LBB0_56
# %bb.55:                               # %L265
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_6
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	vxorpd	xmm1, xmm7, xmmword ptr [rax]
	vmaxsd	xmm1, xmm9, xmm1
	vminsd	xmm0, xmm1, xmm7
	vsubsd	xmm0, xmm9, xmm0
	vaddsd	xmm3, xmm8, xmm0
	jmp	.LBB0_65
.LBB0_63:                               # %L320
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovapd	xmm0, xmm9
	vmovapd	xmm2, xmm14
	xor	edi, edi
	movabs	rax, offset j__sqrt_band_step_1077
	mov	qword ptr [rbp - 64], r12
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	vmovapd	xmm3, xmm0
	jmp	.LBB0_65
.LBB0_47:                               # %L208
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rbx
	vmovapd	xmm0, xmm2
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1078
	mov	qword ptr [rbp - 64], r12
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	vmovapd	xmm3, xmm0
	jmp	.LBB0_65
.LBB0_56:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_7
	vmovapd	xmm1, xmm14
	mov	qword ptr [rbp - 64], r12
	vmovapd	xmmword ptr [rbp - 144], xmm0   # 16-byte Spill
	vmovsd	qword ptr [rbp - 112], xmm14    # 8-byte Spill
	vmovsd	qword ptr [rbp - 104], xmm9     # 8-byte Spill
	vmovsd	xmm2, qword ptr [rax]           # xmm2 = mem[0],zero
	movabs	rax, offset j__exceptional_product_1076
	vzeroupper
	call	rax
	vmovsd	xmm4, qword ptr [rbp - 104]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vxorpd	xmm1, xmm1, xmm1
	vsubsd	xmm2, xmm4, xmm0
	vmovq	rax, xmm2
	vmovapd	xmm3, xmm2
	test	rax, rax
	jns	.LBB0_58
# %bb.57:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm3, xmm3, xmm3
.LBB0_58:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm0, xmm4, xmm0
	vxorpd	xmm4, xmm4, xmm4
	vmovq	rax, xmm0
	test	rax, rax
	jns	.LBB0_60
# %bb.59:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovapd	xmm4, xmm0
.LBB0_60:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vcmpordsd	xmm5, xmm2, xmm2
	vcmpordsd	xmm6, xmm0, xmm0
	mov	cl, 63
	mov	r11, qword ptr [rbp - 48]       # 8-byte Reload
	movabs	rdx, 9218868437227405312
	vblendvpd	xmm2, xmm2, xmm3, xmm5
	vblendvpd	xmm0, xmm0, xmm4, xmm6
	vmovapd	xmm3, xmmword ptr [rbp - 144]   # 16-byte Reload
	vaddsd	xmm0, xmm2, xmm0
	vmovq	xmm2, qword ptr [rbp - 112]     # 8-byte Folded Reload
                                        # xmm2 = mem[0],zero
	vmovq	rax, xmm2
	vmovapd	xmm2, xmm0
	bzhi	rax, rax, rcx
	cmp	rax, rdx
	jne	.LBB0_62
# %bb.61:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm2, xmm2, xmm2
.LBB0_62:                               # %L289
                                        #   in Loop: Header=BB0_6 Depth=2
	vcmpnlesd	xmm1, xmm1, xmm3
	vblendvpd	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_65
.LBB0_11:                               # %L40
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	je	.LBB0_12
# %bb.13:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_15
# %bb.14:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_18
.LBB0_12:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_29
.LBB0_15:                               # %vector.ph306
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_0
	mov	rdi, rcx
	vmovapd	xmm10, xmm7
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
.LBB0_16:                               # %vector.body311
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
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
	jne	.LBB0_16
# %bb.17:                               # %middle.block303
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm4, ymm5, ymm4
	vaddpd	ymm0, ymm0, ymm1
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	cmp	rcx, rdi
	vmovapd	xmm7, xmm10
	vextractf128	xmm1, ymm4, 1
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm1, xmm4, xmm1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm4, xmm1, xmm3
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vpermilpd	xmm1, xmm2, 1           # xmm1 = xmm2[1,0]
	vaddsd	xmm6, xmm2, xmm1
	vaddsd	xmm0, xmm0, xmm3
	je	.LBB0_29
.LBB0_18:                               # %scalar.ph304
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	r9, r8
.LBB0_19:                               # %L54
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [r9 + 8*rdi]    # xmm1 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	add	rdi, 1
	cmp	rcx, rdi
	vfmadd231sd	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231sd	xmm6, xmm2, xmm1        # xmm6 = (xmm2 * xmm1) + xmm6
	vfmadd231sd	xmm4, xmm2, xmm2        # xmm4 = (xmm2 * xmm2) + xmm4
	jne	.LBB0_19
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_66:                               # %L337
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 120]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 96]       # 8-byte Folded Reload
	je	.LBB0_67
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15, qword ptr [r11 + 8]
	add	rax, 1
	jmp	.LBB0_4
.LBB0_67:
	mov	rcx, qword ptr [rbp - 88]       # 8-byte Reload
.LBB0_68:                               # %L348
	mov	rax, qword ptr [rbp - 72]
	vmovapd	xmm0, xmm7
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
.LBB0_7:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_69
.LBB0_9:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_9
.LBB0_69:                               # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_30:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_70
.LBB0_32:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_32
.LBB0_70:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r11
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_75:                               # %L148
	movabs	rax, offset j_throw_complex_domainerror_1075
	movabs	rdi, 126417930070544
	vzeroupper
	call	rax
.LBB0_76:                               # %L213
	movabs	rax, offset j_throw_complex_domainerror_1075
	movabs	rdi, 126417930070544
	vzeroupper
	call	rax
.LBB0_77:                               # %L220
	movabs	rax, offset j_throw_complex_domainerror_1075
	movabs	rdi, 126417930070544
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_78:                               # %L227
	movabs	rax, offset j_throw_complex_domainerror_1075
	movabs	rdi, 126417930070544
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1072, .Lfunc_end0-julia_pass_1072
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
