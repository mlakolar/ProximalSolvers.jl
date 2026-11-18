	.text
	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_pass_711
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
.LCPI0_4:
	.quad	0x0010000000000000              # double 2.2250738585072014E-308
.LCPI0_5:
	.quad	0x7fefffffffffffff              # double 1.7976931348623157E+308
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
	.globl	julia_pass_711
	.p2align	4, 0x90
	.type	julia_pass_711,@function
julia_pass_711:                         # @julia_pass_711
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 136
	vxorpd	xmm0, xmm0, xmm0
	vmovapd	xmmword ptr [rbp - 80], xmm0
	mov	qword ptr [rbp - 64], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 80], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 72], rax
	lea	rax, [rbp - 80]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorpd	xmm1, xmm1, xmm1
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 96], rax       # 8-byte Spill
	jle	.LBB0_70
# %bb.1:                                # %L17.preheader
	mov	r10, rsi
	mov	rax, qword ptr [rsi + 8]
	test	rax, rax
	je	.LBB0_70
# %bb.2:                                # %L17.preheader391
	mov	rbx, rdi
	mov	r15, rax
	mov	qword ptr [rbp - 88], rcx       # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorpd	xmm15, xmm15, xmm15
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rcx]
	vmovups	ymmword ptr [rbp - 176], ymm0   # 32-byte Spill
	movabs	rcx, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [rcx]
	vmovupd	ymmword ptr [rbp - 144], ymm0   # 32-byte Spill
	vxorpd	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 56], rdi       # 8-byte Spill
	mov	qword ptr [rbp - 48], r10       # 8-byte Spill
	.p2align	4, 0x90
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_36 Depth 3
                                        #       Child Loop BB0_49 Depth 3
                                        #       Child Loop BB0_52 Depth 3
	mov	qword ptr [rbp - 104], rax      # 8-byte Spill
	test	r15, r15
	je	.LBB0_68
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	jmp	.LBB0_6
	.p2align	4, 0x90
.LBB0_66:                               # %L320
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r12
	mov	rdi, rbx
	vmovapd	xmm0, xmm3
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_717
	vzeroupper
	call	rax
	mov	r10, qword ptr [rbp - 48]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	vmovapd	xmm4, xmm0
.LBB0_67:                               # %L322
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovsd	xmm1, qword ptr [rbp - 112]     # 8-byte Reload
                                        # xmm1 = mem[0],zero
	vaddsd	xmm1, xmm1, xmm4
	lea	rax, [r14 + 1]
	add	r13, 8
	cmp	r14, r15
	mov	r14, rax
	je	.LBB0_68
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_36 Depth 3
                                        #       Child Loop BB0_49 Depth 3
                                        #       Child Loop BB0_52 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_7
# %bb.10:                               # %idxend
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [r12]
	mov	rax, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovsd	xmm0, qword ptr [rcx + 8*r14 - 8] # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm0
	mov	r11, qword ptr [rax + 8]
	vmovsd	qword ptr [rbp - 112], xmm1     # 8-byte Spill
	jp	.LBB0_11
# %bb.24:                               # %L83
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r11, r11
	je	.LBB0_25
# %bb.26:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_28
# %bb.27:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm6, xmm6, xmm6
	xor	edi, edi
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_35
	.p2align	4, 0x90
.LBB0_25:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_37
	.p2align	4, 0x90
.LBB0_28:                               # %vector.ph283
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_29
# %bb.30:                               # %vector.ph283.new
                                        #   in Loop: Header=BB0_6 Depth=2
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
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm3, ymm1
	vmovapd	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_31:                               # %vector.body288
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vmovupd	ymm7, ymmword ptr [rsi + 8*rax + 64]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rax + 96]
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rcx + 8*rax - 96] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rcx + 8*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231pd	ymm1, ymm7, ymmword ptr [rcx + 8*rax - 32] # ymm1 = (ymm7 * mem) + ymm1
	vfmadd231pd	ymm2, ymm8, ymmword ptr [rcx + 8*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231pd	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 16
	add	rbx, -2
	jne	.LBB0_31
# %bb.32:                               # %middle.block280.unr-lcssa
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r10b, 1
	je	.LBB0_34
.LBB0_33:                               # %vector.body288.epil.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rdx + 8*rcx] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rdx + 8*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_34:                               # %middle.block280
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm1, ymm2, ymm1
	vaddpd	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm5, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddsd	xmm6, xmm1, xmm2
	cmp	r11, rdi
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 48]       # 8-byte Reload
	je	.LBB0_37
.LBB0_35:                               # %scalar.ph281
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_36:                               # %L96
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [rsi + 8*rdi]   # xmm1 = mem[0],zero
	vfmadd231sd	xmm6, xmm1, qword ptr [rdx + 8*rdi] # xmm6 = (xmm1 * mem) + xmm6
	vfmadd231sd	xmm5, xmm1, xmm1        # xmm5 = (xmm1 * xmm1) + xmm5
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_36
.LBB0_37:                               # %L124
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	r9, qword ptr [r10 + 8]
	jae	.LBB0_38
# %bb.73:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [r10]
	vmovsd	xmm3, qword ptr [rax + 8*r14 - 8] # xmm3 = mem[0],zero
	vsubsd	xmm1, xmm0, xmm0
	vucomisd	xmm1, xmm1
	jp	.LBB0_66
# %bb.74:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rbx]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm14, xmm14, xmm14
	vcvtsi2sd	xmm1, xmm14, rax
	movabs	rsi, offset .LCPI0_2
	vmulsd	xmm7, xmm1, qword ptr [rsi]
	vucomisd	xmm0, xmm7
	jb	.LBB0_66
# %bb.75:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm1, xmm5, xmm5
	vucomisd	xmm1, xmm1
	jp	.LBB0_66
# %bb.76:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm5, xmm7
	jb	.LBB0_66
# %bb.41:                               # %L144
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm0
	ja	.LBB0_77
# %bb.42:                               # %L150
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovsd	xmm2, qword ptr [rbx + 8]       # xmm2 = mem[0],zero
	vsqrtsd	xmm1, xmm0, xmm0
	vxorpd	xmm4, xmm4, xmm4
	vucomisd	xmm2, xmm1
	jae	.LBB0_67
# %bb.43:                               # %L155
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm4, xmm6, xmm0
	vmulsd	xmm0, xmm6, xmm4
	vsubsd	xmm0, xmm5, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm5, xmm5, qword ptr [rsi]
	vucomisd	xmm5, xmm0
	jbe	.LBB0_56
# %bb.44:                               # %L162
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	je	.LBB0_45
# %bb.46:                               # %L176.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	cmp	rax, 16
	jae	.LBB0_48
# %bb.47:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_51
.LBB0_29:                               #   in Loop: Header=BB0_6 Depth=2
	xor	eax, eax
	vmovupd	ymm3, ymmword ptr [rbp - 144]   # 32-byte Reload
	vmovapd	ymm1, ymm3
	vmovupd	ymm4, ymmword ptr [rbp - 176]   # 32-byte Reload
	vmovapd	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_34
	jmp	.LBB0_33
.LBB0_45:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_53
.LBB0_48:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rsi, 9223372036854775800
	add	rsi, -8
	and	rsi, rax
	vbroadcastsd	ymm0, xmm4
	mov	rdi, r8
	imul	rdi, r13
	lea	rbx, [rdx + rdi]
	add	rbx, 96
	movabs	rdi, offset .LCPI0_0
	vbroadcastsd	ymm5, qword ptr [rdi]
	movabs	rdi, offset .LCPI0_1
	vmovapd	ymm6, ymmword ptr [rdi]
	xor	edi, edi
	vmovapd	ymm8, ymm5
	vmovapd	ymm9, ymm5
	.p2align	4, 0x90
.LBB0_49:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovupd	ymm10, ymmword ptr [rcx + 8*rdi]
	vmovupd	ymm11, ymmword ptr [rcx + 8*rdi + 32]
	vmovupd	ymm12, ymmword ptr [rcx + 8*rdi + 64]
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdi + 96]
	vmulpd	ymm14, ymm0, ymmword ptr [rbx + 8*rdi - 96]
	vsubpd	ymm10, ymm10, ymm14
	vmulpd	ymm14, ymm0, ymmword ptr [rbx + 8*rdi - 64]
	vsubpd	ymm11, ymm11, ymm14
	vmulpd	ymm14, ymm0, ymmword ptr [rbx + 8*rdi - 32]
	vsubpd	ymm12, ymm12, ymm14
	vmulpd	ymm14, ymm0, ymmword ptr [rbx + 8*rdi]
	vsubpd	ymm13, ymm13, ymm14
	vfmadd231pd	ymm6, ymm10, ymm10      # ymm6 = (ymm10 * ymm10) + ymm6
	vfmadd231pd	ymm5, ymm11, ymm11      # ymm5 = (ymm11 * ymm11) + ymm5
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	vfmadd231pd	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	rdi, 16
	cmp	rsi, rdi
	jne	.LBB0_49
# %bb.50:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm5, ymm6
	vaddpd	ymm0, ymm8, ymm0
	vaddpd	ymm0, ymm9, ymm0
	vextractf128	xmm5, ymm0, 1
	vaddpd	xmm0, xmm0, xmm5
	vpermilpd	xmm5, xmm0, 1           # xmm5 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm5
	cmp	rax, rsi
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_53
.LBB0_51:                               # %scalar.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_52:                               # %L176
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm5, qword ptr [rcx + 8*rsi]   # xmm5 = mem[0],zero
	vmulsd	xmm6, xmm4, qword ptr [rdx + 8*rsi]
	vsubsd	xmm5, xmm5, xmm6
	vfmadd231sd	xmm0, xmm5, xmm5        # xmm0 = (xmm5 * xmm5) + xmm0
	inc	rsi
	cmp	rax, rsi
	jne	.LBB0_52
.LBB0_53:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm0, xmm7
	jb	.LBB0_55
# %bb.54:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm5, xmm0, xmm0
	vucomisd	xmm5, xmm5
	jp	.LBB0_55
.LBB0_56:                               # %L210
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm15, xmm0
	ja	.LBB0_78
# %bb.57:                               # %L215
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubsd	xmm5, xmm1, xmm2
	vucomisd	xmm15, xmm5
	movabs	rax, offset .LCPI0_4
	ja	.LBB0_79
# %bb.58:                               # %L222
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm6, xmm1, xmm2
	vucomisd	xmm15, xmm6
	ja	.LBB0_80
# %bb.59:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddsd	xmm4, xmm4, xmm3
	vsqrtsd	xmm3, xmm0, xmm0
	vsqrtsd	xmm0, xmm5, xmm5
	vsqrtsd	xmm5, xmm6, xmm6
	vmulsd	xmm0, xmm0, xmm5
	vmulsd	xmm0, xmm1, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_65
# %bb.60:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivsd	xmm0, xmm3, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_65
# %bb.61:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rcx, offset .LCPI0_5
	vmovsd	xmm5, qword ptr [rcx]           # xmm5 = mem[0],zero
	vucomisd	xmm5, xmm0
	jb	.LBB0_65
# %bb.62:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulsd	xmm0, xmm2, xmm0
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_65
# %bb.63:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomisd	xmm5, xmm0
	jb	.LBB0_65
# %bb.64:                               # %L263
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm1, xmm0, xmmword ptr [rax]
	vmaxsd	xmm1, xmm4, xmm1
	vminsd	xmm0, xmm1, xmm0
	vsubsd	xmm0, xmm4, xmm0
	vaddsd	xmm4, xmm15, xmm0
	jmp	.LBB0_67
.LBB0_65:                               # %L318
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r12
	vmovapd	xmm0, xmm4
	xor	edi, edi
	movabs	rax, offset j__sqrt_band_step_716
	vzeroupper
	call	rax
	mov	r10, qword ptr [rbp - 48]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	vmovapd	xmm4, xmm0
	jmp	.LBB0_67
.LBB0_55:                               # %L208
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r12
	mov	rdi, rbx
	vmovapd	xmm0, xmm3
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_717
	vzeroupper
	call	rax
	mov	r10, qword ptr [rbp - 48]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	vmovapd	xmm4, xmm0
	jmp	.LBB0_67
.LBB0_11:                               # %L40
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r11, r11
	je	.LBB0_12
# %bb.13:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_15
# %bb.14:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_22
.LBB0_12:                               #   in Loop: Header=BB0_6 Depth=2
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_37
.LBB0_15:                               # %vector.ph306
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_16
# %bb.17:                               # %vector.ph306.new
                                        #   in Loop: Header=BB0_6 Depth=2
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
.LBB0_18:                               # %vector.body311
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
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
	jne	.LBB0_18
	jmp	.LBB0_19
.LBB0_16:                               #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_19:                               # %middle.block303.unr-lcssa
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r10b, 1
	je	.LBB0_21
# %bb.20:                               # %vector.body311.epil.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
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
.LBB0_21:                               # %middle.block303
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddpd	ymm0, ymm0, ymm1
	vaddpd	ymm1, ymm3, ymm2
	vaddpd	ymm2, ymm5, ymm4
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm5, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddpd	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddsd	xmm6, xmm1, xmm2
	vextractf128	xmm1, ymm0, 1
	vaddpd	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm1
	cmp	r11, rdi
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	vxorpd	xmm15, xmm15, xmm15
	mov	r10, qword ptr [rbp - 48]       # 8-byte Reload
	je	.LBB0_37
.LBB0_22:                               # %scalar.ph304
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rcx, r8
.LBB0_23:                               # %L54
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovsd	xmm1, qword ptr [rcx + 8*rdi]   # xmm1 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	vfmadd231sd	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231sd	xmm6, xmm2, xmm1        # xmm6 = (xmm2 * xmm1) + xmm6
	vfmadd231sd	xmm5, xmm2, xmm2        # xmm5 = (xmm2 * xmm2) + xmm5
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_23
	jmp	.LBB0_37
	.p2align	4, 0x90
.LBB0_68:                               # %L335
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 104]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 96]       # 8-byte Folded Reload
	je	.LBB0_69
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r15, qword ptr [r10 + 8]
	jmp	.LBB0_4
.LBB0_69:
	mov	rcx, qword ptr [rbp - 88]       # 8-byte Reload
.LBB0_70:                               # %L346
	mov	rax, qword ptr [rbp - 72]
	mov	qword ptr [rcx], rax
	vmovapd	xmm0, xmm1
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
	jge	.LBB0_71
.LBB0_9:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_9
.LBB0_71:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_38:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_72
.LBB0_40:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_40
.LBB0_72:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r10
	vzeroupper
	call	rax
.LBB0_77:                               # %L148
	movabs	rax, offset j_throw_complex_domainerror_714
	movabs	rdi, 140312453360144
	vzeroupper
	call	rax
.LBB0_78:                               # %L213
	movabs	rax, offset j_throw_complex_domainerror_714
	movabs	rdi, 140312453360144
	vzeroupper
	call	rax
.LBB0_79:                               # %L220
	movabs	rax, offset j_throw_complex_domainerror_714
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_80:                               # %L227
	movabs	rax, offset j_throw_complex_domainerror_714
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm6
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_711, .Lfunc_end0-julia_pass_711
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
