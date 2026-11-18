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
	sub	rsp, 168
	vxorpd	xmm0, xmm0, xmm0
	vmovapd	xmmword ptr [rbp - 96], xmm0
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
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 128], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r15, rsi
	mov	rdx, qword ptr [rsi + 8]
	test	rdx, rdx
	je	.LBB0_3
# %bb.4:                                # %L17.preheader493
	mov	rbx, rdi
	mov	qword ptr [rbp - 120], rcx      # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorpd	xmm14, xmm14, xmm14
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rcx]
	vmovups	ymmword ptr [rbp - 208], ymm0   # 32-byte Spill
	movabs	rcx, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [rcx]
	vmovupd	ymmword ptr [rbp - 176], ymm0   # 32-byte Spill
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vxorpd	xmm0, xmm0, xmm0
	mov	qword ptr [rbp - 64], rdi       # 8-byte Spill
	.p2align	4, 0x90
.LBB0_6:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_8 Depth 2
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_33 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_56 Depth 3
                                        #       Child Loop BB0_53 Depth 3
	mov	qword ptr [rbp - 136], rax      # 8-byte Spill
	test	rdx, rdx
	je	.LBB0_69
# %bb.7:                                # %L31.preheader
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	mov	qword ptr [rbp - 72], rdx       # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_67:                               # %L289
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 80], r12
	mov	rdi, rbx
	mov	rsi, r14
	movabs	rax, offset j__sqrt_cold_1067
	vzeroupper
	call	rax
	vxorpd	xmm14, xmm14, xmm14
	vmovapd	xmm2, xmm0
	mov	r8, qword ptr [rbp - 72]        # 8-byte Reload
.LBB0_68:                               # %L293
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovsd	xmm0, qword ptr [rbp - 144]     # 8-byte Reload
                                        # xmm0 = mem[0],zero
	vaddsd	xmm0, xmm0, xmm2
	lea	rax, [r14 + 1]
	add	r13, 8
	cmp	r14, r8
	mov	r14, rax
	je	.LBB0_69
.LBB0_8:                                # %L31
                                        #   Parent Loop BB0_6 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_33 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_56 Depth 3
                                        #       Child Loop BB0_53 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, qword ptr [r12]
	mov	rax, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovsd	xmm1, qword ptr [rcx + 8*r14 - 8] # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm1
	mov	r11, qword ptr [rax + 8]
	vmovsd	qword ptr [rbp - 144], xmm0     # 8-byte Spill
	jp	.LBB0_13
# %bb.26:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r11, r11
	je	.LBB0_27
# %bb.28:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_30
# %bb.29:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm7, xmm7, xmm7
	xor	edi, edi
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_37
	.p2align	4, 0x90
.LBB0_27:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_30:                               # %vector.ph379
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_31
# %bb.32:                               # %vector.ph379.new
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rbx, r10
	movabs	rax, 4611686018427387902
	and	rbx, rax
	mov	rax, r8
	imul	rax, r13
	lea	rcx, [rdx + rax]
	add	rcx, 96
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm2, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_33:                               # %vector.body384
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vmovupd	ymm7, ymmword ptr [rsi + 8*rax + 64]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rax + 96]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [rcx + 8*rax - 96] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rcx + 8*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231pd	ymm0, ymm7, ymmword ptr [rcx + 8*rax - 32] # ymm0 = (ymm7 * mem) + ymm0
	vfmadd231pd	ymm2, ymm8, ymmword ptr [rcx + 8*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231pd	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 16
	add	rbx, -2
	jne	.LBB0_33
# %bb.34:                               # %middle.block376.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r10b, 1
	je	.LBB0_36
.LBB0_35:                               # %vector.body384.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [rdx + 8*rcx] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rdx + 8*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_36:                               # %middle.block376
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm0, ymm2, ymm0
	vaddpd	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm3, xmm2, xmm3
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddsd	xmm7, xmm0, xmm2
	cmp	r11, rdi
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	je	.LBB0_39
.LBB0_37:                               # %scalar.ph377
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_38:                               # %L96
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [rsi + 8*rdi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm7, xmm0, qword ptr [rdx + 8*rdi] # xmm7 = (xmm0 * mem) + xmm7
	vfmadd231sd	xmm3, xmm0, xmm0        # xmm3 = (xmm0 * xmm0) + xmm3
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_38
.LBB0_39:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=2
	cmp	r9, qword ptr [r15 + 8]
	jae	.LBB0_40
# %bb.75:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [r15]
	vmovsd	xmm0, qword ptr [rax + 8*r14 - 8] # xmm0 = mem[0],zero
	vsubsd	xmm2, xmm1, xmm1
	vucomisd	xmm2, xmm2
	jp	.LBB0_67
# %bb.76:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rbx]
	mov	rcx, qword ptr [rdx + 24]
	mov	rax, qword ptr [rcx + 8]
	vcvtsi2sd	xmm2, xmm15, rax
	movabs	rsi, offset .LCPI0_2
	vmulsd	xmm2, xmm2, qword ptr [rsi]
	vucomisd	xmm1, xmm2
	jb	.LBB0_67
# %bb.77:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubsd	xmm4, xmm3, xmm3
	vucomisd	xmm4, xmm4
	jp	.LBB0_67
# %bb.78:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm3, xmm2
	jb	.LBB0_67
# %bb.43:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm14, xmm1
	ja	.LBB0_79
# %bb.44:                               # %L152
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovsd	xmm4, qword ptr [rbx + 8]       # xmm4 = mem[0],zero
	vsqrtsd	xmm5, xmm1, xmm1
	vxorpd	xmm2, xmm2, xmm2
	vucomisd	xmm4, xmm5
	jae	.LBB0_45
# %bb.46:                               # %L157
                                        #   in Loop: Header=BB0_8 Depth=2
	vdivsd	xmm6, xmm7, xmm1
	vmulsd	xmm1, xmm7, xmm6
	vsubsd	xmm1, xmm3, xmm1
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm2, xmm3, qword ptr [rsi]
	vucomisd	xmm2, xmm1
	mov	r8, qword ptr [rbp - 72]        # 8-byte Reload
	jbe	.LBB0_59
# %bb.47:                               # %L163
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rdx]
	mov	rdx, qword ptr [rdi + 24]
	mov	qword ptr [rbp - 48], rdx       # 8-byte Spill
	cmp	r9, qword ptr [rdi + 32]
	jae	.LBB0_80
# %bb.48:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rax, rax
	je	.LBB0_49
# %bb.50:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rcx, qword ptr [rcx]
	mov	rdx, qword ptr [rdi]
	cmp	rax, 16
	jae	.LBB0_55
# %bb.51:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	esi, esi
	jmp	.LBB0_52
	.p2align	4, 0x90
.LBB0_45:                               #   in Loop: Header=BB0_8 Depth=2
	mov	r8, qword ptr [rbp - 72]        # 8-byte Reload
	jmp	.LBB0_68
.LBB0_31:                               #   in Loop: Header=BB0_8 Depth=2
	xor	eax, eax
	vmovupd	ymm3, ymmword ptr [rbp - 176]   # 32-byte Reload
	vmovapd	ymm0, ymm3
	vmovupd	ymm4, ymmword ptr [rbp - 208]   # 32-byte Reload
	vmovapd	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_36
	jmp	.LBB0_35
.LBB0_49:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_60
.LBB0_55:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	movabs	rsi, 9223372036854775800
	add	rsi, -8
	and	rsi, rax
	vbroadcastsd	ymm1, xmm6
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdi, r13
	add	rdi, rdx
	add	rdi, 96
	movabs	rbx, offset .LCPI0_0
	vbroadcastsd	ymm2, qword ptr [rbx]
	movabs	rbx, offset .LCPI0_1
	vmovapd	ymm3, ymmword ptr [rbx]
	xor	ebx, ebx
	vmovapd	ymm7, ymm2
	vmovapd	ymm8, ymm2
	.p2align	4, 0x90
.LBB0_56:                               # %vector.body
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm9, ymmword ptr [rcx + 8*rbx]
	vmovupd	ymm10, ymmword ptr [rcx + 8*rbx + 32]
	vmovupd	ymm11, ymmword ptr [rcx + 8*rbx + 64]
	vmovupd	ymm12, ymmword ptr [rcx + 8*rbx + 96]
	vmulpd	ymm13, ymm1, ymmword ptr [rdi + 8*rbx - 96]
	vsubpd	ymm9, ymm9, ymm13
	vmulpd	ymm13, ymm1, ymmword ptr [rdi + 8*rbx - 64]
	vsubpd	ymm10, ymm10, ymm13
	vmulpd	ymm13, ymm1, ymmword ptr [rdi + 8*rbx - 32]
	vsubpd	ymm11, ymm11, ymm13
	vmulpd	ymm13, ymm1, ymmword ptr [rdi + 8*rbx]
	vsubpd	ymm12, ymm12, ymm13
	vfmadd231pd	ymm3, ymm9, ymm9        # ymm3 = (ymm9 * ymm9) + ymm3
	vfmadd231pd	ymm2, ymm10, ymm10      # ymm2 = (ymm10 * ymm10) + ymm2
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	add	rbx, 16
	cmp	rsi, rbx
	jne	.LBB0_56
# %bb.57:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm1, ymm2, ymm3
	vaddpd	ymm1, ymm7, ymm1
	vaddpd	ymm1, ymm8, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddsd	xmm1, xmm1, xmm2
	cmp	rax, rsi
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	jne	.LBB0_52
# %bb.58:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_59
.LBB0_52:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdi, r13
	add	rdx, rdi
	.p2align	4, 0x90
.LBB0_53:                               # %L208
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vmulsd	xmm3, xmm6, qword ptr [rdx + 8*rsi]
	vsubsd	xmm2, xmm2, xmm3
	vfmadd231sd	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	inc	rsi
	cmp	rax, rsi
	jne	.LBB0_53
# %bb.54:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
.LBB0_59:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomisd	xmm14, xmm1
	ja	.LBB0_81
.LBB0_60:                               # %L252
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubsd	xmm2, xmm5, xmm4
	vucomisd	xmm14, xmm2
	ja	.LBB0_82
# %bb.61:                               # %L259
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm3, xmm5, xmm4
	vucomisd	xmm14, xmm3
	ja	.LBB0_83
# %bb.62:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm6, xmm6, xmm0
	vdivsd	xmm0, xmm4, xmm5
	vsqrtsd	xmm1, xmm1, xmm1
	vsqrtsd	xmm2, xmm2, xmm2
	vsqrtsd	xmm3, xmm3, xmm3
	vmulsd	xmm2, xmm2, xmm3
	vdivsd	xmm1, xmm1, xmm2
	vmulsd	xmm3, xmm0, xmm1
	vsubsd	xmm0, xmm6, xmm3
	vmovq	rax, xmm0
	vxorpd	xmm1, xmm1, xmm1
	vmovapd	xmm2, xmm0
	test	rax, rax
	jns	.LBB0_64
# %bb.63:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm2, xmm2, xmm2
.LBB0_64:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddsd	xmm3, xmm6, xmm3
	vmovq	rax, xmm3
	test	rax, rax
	jns	.LBB0_66
# %bb.65:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovapd	xmm1, xmm3
.LBB0_66:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vcmpordsd	xmm4, xmm0, xmm0
	vblendvpd	xmm0, xmm0, xmm2, xmm4
	vcmpordsd	xmm2, xmm3, xmm3
	vblendvpd	xmm1, xmm3, xmm1, xmm2
	vaddsd	xmm2, xmm0, xmm1
	jmp	.LBB0_68
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r11, r11
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rcx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_24
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=2
	vxorpd	xmm3, xmm3, xmm3
	vxorpd	xmm7, xmm7, xmm7
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_39
.LBB0_17:                               # %vector.ph402
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_18
# %bb.19:                               # %vector.ph402.new
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rbx, r10
	movabs	rax, 4611686018427387902
	and	rbx, rax
	mov	rax, r8
	imul	rax, r13
	lea	rdx, [rcx + rax]
	add	rdx, 96
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_20:                               # %vector.body407
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm6, ymmword ptr [rdx + 8*rax - 96]
	vmovupd	ymm7, ymmword ptr [rdx + 8*rax - 64]
	vmovupd	ymm8, ymmword ptr [rdx + 8*rax - 32]
	vmovupd	ymm9, ymmword ptr [rdx + 8*rax]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vmovupd	ymm10, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm11, ymmword ptr [rsi + 8*rax + 32]
	vmovupd	ymm12, ymmword ptr [rsi + 8*rax + 64]
	vmovupd	ymm13, ymmword ptr [rsi + 8*rax + 96]
	vfmadd231pd	ymm2, ymm10, ymm6       # ymm2 = (ymm10 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm11, ymm7       # ymm3 = (ymm11 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231pd	ymm5, ymm11, ymm11      # ymm5 = (ymm11 * ymm11) + ymm5
	vfmadd231pd	ymm1, ymm8, ymm8        # ymm1 = (ymm8 * ymm8) + ymm1
	vfmadd231pd	ymm0, ymm9, ymm9        # ymm0 = (ymm9 * ymm9) + ymm0
	vfmadd231pd	ymm2, ymm12, ymm8       # ymm2 = (ymm12 * ymm8) + ymm2
	vfmadd231pd	ymm3, ymm13, ymm9       # ymm3 = (ymm13 * ymm9) + ymm3
	vfmadd231pd	ymm4, ymm12, ymm12      # ymm4 = (ymm12 * ymm12) + ymm4
	vfmadd231pd	ymm5, ymm13, ymm13      # ymm5 = (ymm13 * ymm13) + ymm5
	add	rax, 16
	add	rbx, -2
	jne	.LBB0_20
	jmp	.LBB0_21
.LBB0_18:                               #   in Loop: Header=BB0_8 Depth=2
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_21:                               # %middle.block399.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r10b, 1
	je	.LBB0_23
# %bb.22:                               # %vector.body407.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, r8
	imul	rdx, r9
	add	rdx, rax
	vmovupd	ymm6, ymmword ptr [rcx + 8*rdx]
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx + 32]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm9, ymmword ptr [rsi + 8*rax + 32]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm7        # ymm3 = (ymm9 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
.LBB0_23:                               # %middle.block399
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddpd	ymm0, ymm0, ymm1
	vaddpd	ymm1, ymm3, ymm2
	vaddpd	ymm2, ymm5, ymm4
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm3, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddsd	xmm7, xmm1, xmm2
	vextractf128	xmm1, ymm0, 1
	vaddpd	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddsd	xmm1, xmm0, xmm1
	cmp	r11, rdi
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	je	.LBB0_39
.LBB0_24:                               # %scalar.ph400
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	rcx, r8
.LBB0_25:                               # %L54
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm0, qword ptr [rcx + 8*rdi]   # xmm0 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm7, xmm2, xmm0        # xmm7 = (xmm2 * xmm0) + xmm7
	vfmadd231sd	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_25
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_69:                               # %L305
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	rax, qword ptr [rbp - 136]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 128]      # 8-byte Folded Reload
	je	.LBB0_70
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_6 Depth=1
	inc	rax
	mov	rdx, qword ptr [r15 + 8]
	jmp	.LBB0_6
.LBB0_70:
	mov	rcx, qword ptr [rbp - 120]      # 8-byte Reload
	mov	rdx, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_71
.LBB0_1:
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_72
.LBB0_3:
	vxorpd	xmm0, xmm0, xmm0
                                        # implicit-def: $rdx
                                        # implicit-def: $rax
                                        # kill: killed $rax
.LBB0_71:                               # %L316.loopexit
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 112], rax
	mov	qword ptr [rbp - 104], rdx
.LBB0_72:                               # %L316
	mov	rax, qword ptr [rbp - 88]
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
	jge	.LBB0_73
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_73:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_40:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_74
.LBB0_42:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_42
.LBB0_74:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r15
	vzeroupper
	call	rax
.LBB0_79:                               # %L150
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_82:                               # %L257
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_83:                               # %L264
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_81:                               # %L250
	movabs	rax, offset j_throw_complex_domainerror_1064
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_80:                               # %L181
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 112], rax
	mov	qword ptr [rbp - 104], r14
	mov	qword ptr [rbp - 80], rdi
	movabs	rax, offset j_throw_boundserror_1066
	lea	rsi, [rbp - 112]
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1061, .Lfunc_end0-julia_pass_1061
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
