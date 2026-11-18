	.text
	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_pass_1303
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
	.globl	julia_pass_1303
	.p2align	4, 0x90
	.type	julia_pass_1303,@function
julia_pass_1303:                        # @julia_pass_1303
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 352
	mov	rbx, rsp
	vxorpd	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	vmovapd	ymmword ptr [rbx + 32], ymm0
	mov	qword ptr [rbx + 72], 0
	mov	qword ptr [rbx + 64], 0
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 32], 16
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbx + 40], rax
	lea	rax, [rbx + 32]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbx + 120], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	rdx, qword ptr [rsi + 8]
	mov	r13, rsi
	mov	qword ptr [rbx + 112], rcx      # 8-byte Spill
	test	rdx, rdx
	je	.LBB0_3
# %bb.4:                                # %L17.preheader520
	mov	rax, qword ptr [rdi]
	movabs	rsi, offset .LCPI0_0
	vxorpd	xmm10, xmm10, xmm10
	mov	ecx, 1
	vxorpd	xmm7, xmm7, xmm7
                                        # implicit-def: $r15
	mov	qword ptr [rbx + 16], rdi       # 8-byte Spill
	mov	qword ptr [rbx + 144], r13      # 8-byte Spill
	vbroadcastsd	ymm0, qword ptr [rsi]
	mov	qword ptr [rbx + 8], rax        # 8-byte Spill
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
                                        # implicit-def: $rax
	vmovapd	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vmovapd	ymmword ptr [rbx + 256], ymm1   # 32-byte Spill
	test	rdx, rdx
	je	.LBB0_70
	.p2align	4, 0x90
.LBB0_7:                                # %L31.preheader
	mov	r12d, 1
	xor	r14d, r14d
	mov	qword ptr [rbx + 128], rcx      # 8-byte Spill
	mov	qword ptr [rbx + 152], rdx      # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_67:                               # %L356
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 8]        # 8-byte Reload
	mov	qword ptr [rbx + 56], rdi
	mov	qword ptr [rbx + 160], rdi
	mov	rdi, rsi
	lea	rsi, [rbx + 160]
	lea	rcx, [rbx + 24]
	mov	r8, r12
	mov	qword ptr [rbx + 168], r15
	mov	qword ptr [rbx + 176], r12
	mov	qword ptr [rbx + 184], r9
	mov	qword ptr [rbx + 192], 1
	vmovsd	qword ptr [rbx], xmm7           # 8-byte Spill
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset j__sqrt_cold_1309
	mov	qword ptr [rbx + 64], rdx
	vzeroupper
	call	rax
	vmovsd	xmm7, qword ptr [rbx]           # 8-byte Reload
                                        # xmm7 = mem[0],zero
	vxorpd	xmm10, xmm10, xmm10
	vmovapd	xmm3, xmm0
.LBB0_68:                               # %L360
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 152]      # 8-byte Reload
	vaddsd	xmm7, xmm7, xmm3
	mov	r13, qword ptr [rbx + 144]      # 8-byte Reload
	add	r14, 8
	cmp	r12, rax
	lea	r12, [r12 + 1]
	je	.LBB0_69
.LBB0_8:                                # %L31
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_18 Depth 2
                                        #     Child Loop BB0_21 Depth 2
                                        #     Child Loop BB0_27 Depth 2
                                        #     Child Loop BB0_30 Depth 2
                                        #     Child Loop BB0_47 Depth 2
                                        #     Child Loop BB0_50 Depth 2
	mov	rcx, qword ptr [rbx + 8]        # 8-byte Reload
	lea	r9, [r12 - 1]
	mov	rdi, qword ptr [rcx + 32]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdx, qword ptr [rcx]
	mov	rcx, qword ptr [rcx + 24]
	vmovsd	xmm1, qword ptr [rax + 8*r12 - 8] # xmm1 = mem[0],zero
	mov	r11, qword ptr [rcx + 8]
	vucomisd	xmm1, xmm1
	jp	.LBB0_13
# %bb.22:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r11, r11
	je	.LBB0_23
# %bb.24:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rdx]
	mov	r8, qword ptr [rdx + 24]
	mov	rdx, qword ptr [rcx]
	cmp	r11, 8
	jae	.LBB0_26
# %bb.25:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm5, xmm5, xmm5
	xor	esi, esi
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_23:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm5, xmm5, xmm5
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_26:                               # %vector.ph415
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, r11
	movabs	rcx, 9223372036854775800
	vmovapd	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	vmovapd	ymm4, ymmword ptr [rbx + 288]   # 32-byte Reload
	and	rsi, rcx
	mov	rcx, r8
	imul	rcx, r14
	vmovapd	ymm0, ymm3
	vmovapd	ymm2, ymm4
	lea	rdi, [rax + rcx + 32]
	xor	ecx, ecx
	.p2align	4, 0x90
.LBB0_27:                               # %vector.body420
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm5, ymmword ptr [rdx + 8*rcx]
	vmovupd	ymm6, ymmword ptr [rdx + 8*rcx + 32]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [rdi + 8*rcx - 32] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rdi + 8*rcx] # ymm2 = (ymm6 * mem) + ymm2
	add	rcx, 8
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rsi, rcx
	jne	.LBB0_27
# %bb.28:                               # %middle.block412
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm3, ymm4, ymm3
	vaddpd	ymm0, ymm2, ymm0
	cmp	r11, rsi
	vextractf128	xmm2, ymm3, 1
	vaddpd	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm5, xmm0, 1           # xmm5 = xmm0[1,0]
	vaddsd	xmm4, xmm2, xmm3
	vaddsd	xmm5, xmm0, xmm5
	je	.LBB0_31
.LBB0_29:                               # %scalar.ph413
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	rax, r8
	.p2align	4, 0x90
.LBB0_30:                               # %L96
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rdx + 8*rsi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm5, xmm0, qword ptr [rax + 8*rsi] # xmm5 = (xmm0 * mem) + xmm5
	add	rsi, 1
	vfmadd231sd	xmm4, xmm0, xmm0        # xmm4 = (xmm0 * xmm0) + xmm4
	cmp	r11, rsi
	jne	.LBB0_30
.LBB0_31:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=1
	cmp	r9, qword ptr [r13 + 8]
	jae	.LBB0_32
# %bb.75:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rax, qword ptr [rsi]
	mov	rdi, qword ptr [rax]
	cmp	r9, qword ptr [rdi + 32]
	mov	r15, qword ptr [rdi + 24]
	jae	.LBB0_76
# %bb.35:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, qword ptr [r13]
	vsubsd	xmm0, xmm1, xmm1
	imul	r9, r15
	mov	rdx, qword ptr [rax + 24]
	mov	r13, qword ptr [rsi + 8]
	vucomisd	xmm0, xmm0
	vmovsd	xmm0, qword ptr [rcx + 8*r12 - 8] # xmm0 = mem[0],zero
	mov	qword ptr [rbx + 24], r13
	jp	.LBB0_67
# %bb.36:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r10, qword ptr [rdx + 8]
	movabs	rax, offset .LCPI0_2
	vxorps	xmm12, xmm12, xmm12
	vcvtsi2sd	xmm2, xmm12, r10
	vmulsd	xmm2, xmm2, qword ptr [rax]
	vucomisd	xmm1, xmm2
	jb	.LBB0_67
# %bb.37:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubsd	xmm3, xmm4, xmm4
	vucomisd	xmm3, xmm3
	jp	.LBB0_67
# %bb.38:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm4, xmm2
	jb	.LBB0_67
# %bb.39:                               # %L179
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm10, xmm1
	ja	.LBB0_77
# %bb.40:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtsd	xmm6, xmm1, xmm1
	vmovq	xmm15, r13
	vxorpd	xmm3, xmm3, xmm3
	vucomisd	xmm15, xmm6
	jae	.LBB0_68
# %bb.41:                               # %L189
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivsd	xmm2, xmm5, xmm1
	movabs	rax, offset .LCPI0_3
	vmulsd	xmm3, xmm5, xmm2
	vmulsd	xmm5, xmm4, qword ptr [rax]
	vsubsd	xmm3, xmm4, xmm3
	vucomisd	xmm5, xmm3
	jbe	.LBB0_51
# %bb.42:                               # %L196
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10, r10
	je	.LBB0_43
# %bb.44:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rdx]
	mov	r8, qword ptr [rdi]
	cmp	r10, 16
	jae	.LBB0_46
# %bb.45:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
	xor	eax, eax
	jmp	.LBB0_49
.LBB0_43:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_52
.LBB0_46:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rcx, offset .LCPI0_0
	movabs	rsi, offset .LCPI0_1
	movabs	rax, 9223372036854775800
	vbroadcastsd	ymm4, xmm2
	vbroadcastsd	ymm3, qword ptr [rcx]
	mov	rcx, r15
	vmovapd	ymm5, ymmword ptr [rsi]
	add	rax, -8
	xor	esi, esi
	imul	rcx, r14
	and	rax, r10
	vmovapd	ymm8, ymm3
	vmovapd	ymm9, ymm3
	add	rcx, r8
	add	rcx, 96
	.p2align	4, 0x90
.LBB0_47:                               # %vector.body
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulpd	ymm10, ymm4, ymmword ptr [rcx + 8*rsi - 96]
	vmulpd	ymm11, ymm4, ymmword ptr [rcx + 8*rsi - 64]
	vmulpd	ymm12, ymm4, ymmword ptr [rcx + 8*rsi - 32]
	vmovupd	ymm14, ymmword ptr [r11 + 8*rsi]
	vmulpd	ymm13, ymm4, ymmword ptr [rcx + 8*rsi]
	vsubpd	ymm10, ymm14, ymm10
	vmovupd	ymm14, ymmword ptr [r11 + 8*rsi + 32]
	vsubpd	ymm11, ymm14, ymm11
	vmovupd	ymm14, ymmword ptr [r11 + 8*rsi + 64]
	vfmadd231pd	ymm5, ymm10, ymm10      # ymm5 = (ymm10 * ymm10) + ymm5
	vsubpd	ymm12, ymm14, ymm12
	vmovupd	ymm14, ymmword ptr [r11 + 8*rsi + 96]
	add	rsi, 16
	vfmadd231pd	ymm3, ymm11, ymm11      # ymm3 = (ymm11 * ymm11) + ymm3
	cmp	rax, rsi
	vsubpd	ymm13, ymm14, ymm13
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	vfmadd231pd	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	jne	.LBB0_47
# %bb.48:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm3, ymm3, ymm5
	cmp	r10, rax
	vxorpd	xmm10, xmm10, xmm10
	vaddpd	ymm3, ymm8, ymm3
	vaddpd	ymm3, ymm9, ymm3
	vextractf128	xmm4, ymm3, 1
	vaddpd	xmm3, xmm3, xmm4
	vpermilpd	xmm4, xmm3, 1           # xmm4 = xmm3[1,0]
	vaddsd	xmm3, xmm3, xmm4
	je	.LBB0_51
.LBB0_49:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r15
	imul	rcx, r14
	add	r8, rcx
	.p2align	4, 0x90
.LBB0_50:                               # %L208
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm4, xmm2, qword ptr [r8 + 8*rax]
	vmovsd	xmm5, qword ptr [r11 + 8*rax]   # xmm5 = mem[0],zero
	add	rax, 1
	cmp	r10, rax
	vsubsd	xmm4, xmm5, xmm4
	vfmadd231sd	xmm3, xmm4, xmm4        # xmm3 = (xmm4 * xmm4) + xmm3
	jne	.LBB0_50
.LBB0_51:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm10, xmm3
	ja	.LBB0_78
.LBB0_52:                               # %L250
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubsd	xmm4, xmm6, xmm15
	vucomisd	xmm10, xmm4
	ja	.LBB0_79
# %bb.53:                               # %L257
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm5, xmm15, xmm6
	vucomisd	xmm10, xmm5
	ja	.LBB0_80
# %bb.54:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtsd	xmm4, xmm4, xmm4
	vsqrtsd	xmm5, xmm5, xmm5
	vsqrtsd	xmm3, xmm3, xmm3
	movabs	rsi, offset .LCPI0_5
	vmovsd	qword ptr [rbx], xmm7           # 8-byte Spill
	vmulsd	xmm4, xmm4, xmm5
	vucomisd	xmm3, xmm10
	setnp	cl
	sete	al
	vmulsd	xmm5, xmm6, xmm4
	vmovsd	xmm4, qword ptr [rsi]           # xmm4 = mem[0],zero
	vucomisd	xmm5, xmm4
	jb	.LBB0_66
# %bb.55:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivsd	xmm7, xmm3, xmm5
	movabs	rsi, offset .LCPI0_4
	and	al, cl
	vmovsd	xmm5, qword ptr [rsi]           # xmm5 = mem[0],zero
	vmulsd	xmm3, xmm15, xmm7
	vcmplepd	xmm8, xmm7, xmm5
	vcmplepd	xmm6, xmm4, xmm7
	vandpd	xmm6, xmm8, xmm6
	vmovd	ecx, xmm6
	vcmplepd	xmm5, xmm3, xmm5
	vcmplepd	xmm4, xmm4, xmm3
	vandpd	xmm4, xmm4, xmm5
	vmovd	esi, xmm4
	and	esi, ecx
	or	sil, al
	test	sil, 1
	je	.LBB0_66
# %bb.56:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_5
	vaddsd	xmm4, xmm2, xmm0
	vucomisd	xmm3, qword ptr [rax]
	jb	.LBB0_59
# %bb.57:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_4
	vmovsd	xmm0, qword ptr [rax]           # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm3
	jb	.LBB0_59
# %bb.58:                               # %L299
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_6
	vmovsd	xmm7, qword ptr [rbx]           # 8-byte Reload
                                        # xmm7 = mem[0],zero
	vxorpd	xmm0, xmm3, xmmword ptr [rax]
	vmaxsd	xmm0, xmm4, xmm0
	vminsd	xmm0, xmm0, xmm3
	vsubsd	xmm0, xmm4, xmm0
	vaddsd	xmm3, xmm10, xmm0
	jmp	.LBB0_68
.LBB0_66:                               # %L354
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 8]        # 8-byte Reload
	mov	qword ptr [rbx + 48], rdi
	mov	qword ptr [rbx + 200], rdi
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	lea	rsi, [rbx + 200]
	lea	rcx, [rbx + 24]
	mov	r8, r12
	mov	qword ptr [rbx + 208], r15
	mov	qword ptr [rbx + 216], r12
	mov	qword ptr [rbx + 224], r9
	mov	qword ptr [rbx + 232], 1
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset j__sqrt_cold_1309
	mov	qword ptr [rbx + 64], rdx
	vzeroupper
	call	rax
	vmovsd	xmm7, qword ptr [rbx]           # 8-byte Reload
                                        # xmm7 = mem[0],zero
	vxorpd	xmm10, xmm10, xmm10
	vmovapd	xmm3, xmm0
	jmp	.LBB0_68
.LBB0_59:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 8]        # 8-byte Reload
	movabs	rcx, offset .LCPI0_7
	vmovapd	xmm0, xmm7
	vmovapd	xmm1, xmm15
	vmovapd	xmmword ptr [rbx + 240], xmm7   # 16-byte Spill
	vmovsd	qword ptr [rbx + 136], xmm4     # 8-byte Spill
	vmovsd	xmm2, qword ptr [rcx]           # xmm2 = mem[0],zero
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset j__exceptional_product_1308
	vzeroupper
	call	rax
	vmovsd	xmm4, qword ptr [rbx + 136]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vxorpd	xmm1, xmm1, xmm1
	vsubsd	xmm2, xmm4, xmm0
	vmovq	rax, xmm2
	vmovapd	xmm3, xmm2
	test	rax, rax
	jns	.LBB0_61
# %bb.60:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
.LBB0_61:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm0, xmm4, xmm0
	vxorpd	xmm4, xmm4, xmm4
	vmovq	rax, xmm0
	test	rax, rax
	jns	.LBB0_63
# %bb.62:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovapd	xmm4, xmm0
.LBB0_63:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpordsd	xmm5, xmm2, xmm2
	vcmpordsd	xmm6, xmm0, xmm0
	mov	al, 63
	vmovsd	xmm7, qword ptr [rbx]           # 8-byte Reload
                                        # xmm7 = mem[0],zero
	movabs	rcx, 9218868437227405312
	vxorpd	xmm10, xmm10, xmm10
	bzhi	rax, r13, rax
	cmp	rax, rcx
	vblendvpd	xmm2, xmm2, xmm3, xmm5
	vblendvpd	xmm0, xmm0, xmm4, xmm6
	vmovapd	xmm3, xmmword ptr [rbx + 240]   # 16-byte Reload
	vaddsd	xmm0, xmm2, xmm0
	vmovapd	xmm2, xmm0
	jne	.LBB0_65
# %bb.64:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm2, xmm2, xmm2
.LBB0_65:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpnlesd	xmm1, xmm1, xmm3
	vblendvpd	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_68
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r11, r11
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r10, qword ptr [rdx]
	mov	r8, qword ptr [rdx + 24]
	mov	rsi, qword ptr [rcx]
	cmp	r11, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_20
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm5, xmm5, xmm5
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_31
.LBB0_17:                               # %vector.ph438
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_0
	mov	rdi, r11
	movabs	rcx, offset .LCPI0_1
	xor	edx, edx
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, 9223372036854775800
	vmovapd	ymm1, ymmword ptr [rcx]
	and	rdi, rax
	mov	rax, r8
	imul	rax, r14
	vmovapd	ymm2, ymm1
	vmovapd	ymm4, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm5, ymm0
	add	rax, r10
	add	rax, 32
.LBB0_18:                               # %vector.body443
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm6, ymmword ptr [rax + 8*rdx - 32]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rdx]
	vmovupd	ymm11, ymmword ptr [rax + 8*rdx]
	vmovupd	ymm9, ymmword ptr [rsi + 8*rdx + 32]
	add	rdx, 8
	cmp	rdi, rdx
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm11, ymm11      # ymm0 = (ymm11 * ymm11) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm11       # ymm3 = (ymm9 * ymm11) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
	jne	.LBB0_18
# %bb.19:                               # %middle.block435
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm4, ymm5, ymm4
	vaddpd	ymm0, ymm0, ymm1
	cmp	r11, rdi
	vextractf128	xmm1, ymm4, 1
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm1, xmm4, xmm1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm4, xmm1, xmm3
	vpermilpd	xmm1, xmm2, 1           # xmm1 = xmm2[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm5, xmm2, xmm1
	vaddsd	xmm1, xmm0, xmm3
	je	.LBB0_31
.LBB0_20:                               # %scalar.ph436
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	r10, r8
.LBB0_21:                               # %L54
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [r10 + 8*rdi]   # xmm0 = mem[0],zero
	vmovsd	xmm2, qword ptr [rsi + 8*rdi]   # xmm2 = mem[0],zero
	add	rdi, 1
	cmp	r11, rdi
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm5, xmm2, xmm0        # xmm5 = (xmm2 * xmm0) + xmm5
	vfmadd231sd	xmm4, xmm2, xmm2        # xmm4 = (xmm2 * xmm2) + xmm4
	jne	.LBB0_21
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_69:
	mov	rcx, qword ptr [rbx + 128]      # 8-byte Reload
.LBB0_70:                               # %L372
                                        # =>This Inner Loop Header: Depth=1
	cmp	rcx, qword ptr [rbx + 120]      # 8-byte Folded Reload
	je	.LBB0_71
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_70 Depth=1
	mov	rdx, qword ptr [r13 + 8]
	add	rcx, 1
	test	rdx, rdx
	jne	.LBB0_7
	jmp	.LBB0_70
.LBB0_1:
	vxorpd	xmm7, xmm7, xmm7
	jmp	.LBB0_72
.LBB0_3:
	vxorpd	xmm7, xmm7, xmm7
                                        # implicit-def: $rax
                                        # implicit-def: $r15
.LBB0_71:                               # %L383.loopexit
	mov	rcx, qword ptr [rbx + 112]      # 8-byte Reload
	mov	qword ptr [rbx + 96], r15
	mov	qword ptr [rbx + 104], rax
.LBB0_72:                               # %L383
	mov	rax, qword ptr [rbx + 40]
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
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r12
	vzeroupper
	call	rax
.LBB0_32:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_74
.LBB0_34:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_34
.LBB0_74:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r13
	mov	qword ptr [rsi], r12
	vzeroupper
	call	rax
.LBB0_76:                               # %L145
	movabs	rax, offset j_throw_boundserror_1310
	lea	rsi, [rbx + 96]
	mov	qword ptr [rbx + 96], r15
	mov	qword ptr [rbx + 104], r12
	mov	qword ptr [rbx + 64], rdi
	vzeroupper
	call	rax
.LBB0_77:                               # %L182
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_79:                               # %L255
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_80:                               # %L262
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_78:                               # %L248
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 136709640595984
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1303, .Lfunc_end0-julia_pass_1303
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
