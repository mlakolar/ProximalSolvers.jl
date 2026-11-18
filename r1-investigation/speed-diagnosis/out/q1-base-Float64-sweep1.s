	.text
	.file	"_sweep!"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia__sweep!_722
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
.LCPI0_7:
	.quad	0x7fffffffffffffff              # double NaN
	.quad	0x7fffffffffffffff              # double NaN
	.text
	.globl	"julia__sweep!_722"
	.p2align	4, 0x90
	.type	"julia__sweep!_722",@function
"julia__sweep!_722":                    # @"julia__sweep!_722"
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 320
	mov	rbx, rsp
	vxorpd	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	r15, r9
	mov	qword ptr [rbx + 32], rsi       # 8-byte Spill
	mov	dword ptr [rbx + 140], r8d      # 4-byte Spill
	mov	qword ptr [rbx + 184], rdx      # 8-byte Spill
	mov	qword ptr [rbx + 40], rdi       # 8-byte Spill
	vmovapd	ymmword ptr [rbx + 96], ymm0
	mov	qword ptr [rbx + 128], 0
	lea	rsi, [rbx + 96]
	mov	rdx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 96], 12
	mov	rax, qword ptr [rdx]
	mov	qword ptr [rbx + 104], rax
	mov	qword ptr [rdx], rsi
	test	byte ptr [rcx], 1
	jne	.LBB0_1
# %bb.105:                              # %L527
	mov	rax, qword ptr [r15]
	xor	ecx, ecx
	test	rax, rax
	cmovg	rcx, rax
	mov	qword ptr [rbx + 152], rcx      # 8-byte Spill
	jle	.LBB0_106
# %bb.107:                              # %L543.preheader
	movabs	rax, offset .LCPI0_0
	vxorpd	xmm14, xmm14, xmm14
	mov	r15d, 1
	xor	r14d, r14d
	mov	qword ptr [rbx + 144], rdx      # 8-byte Spill
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovapd	ymm0, ymmword ptr [rax]
	xor	eax, eax
	mov	qword ptr [rbx + 24], rax       # 8-byte Spill
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovapd	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_108:                              # %L543
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_118 Depth 2
                                        #     Child Loop BB0_121 Depth 2
                                        #     Child Loop BB0_127 Depth 2
                                        #     Child Loop BB0_130 Depth 2
                                        #     Child Loop BB0_137 Depth 2
                                        #     Child Loop BB0_157 Depth 2
                                        #     Child Loop BB0_160 Depth 2
                                        #     Child Loop BB0_195 Depth 2
                                        #     Child Loop BB0_198 Depth 2
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	lea	r12, [r15 - 1]
	mov	r13, qword ptr [rax]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_109
# %bb.112:                              # %idxend284
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovsd	qword ptr [rbx + 176], xmm0     # 8-byte Spill
	vmovsd	xmm15, qword ptr [rax + 8*r15 - 8] # xmm15 = mem[0],zero
	mov	rax, qword ptr [r13]
	mov	r11, qword ptr [rdi + 8]
	vucomisd	xmm15, xmm15
	jp	.LBB0_113
# %bb.122:                              # %L606
                                        #   in Loop: Header=BB0_108 Depth=1
	test	r11, r11
	je	.LBB0_123
# %bb.124:                              # %L619.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	r9, qword ptr [rax]
	mov	r8, qword ptr [rax + 24]
	mov	rdx, qword ptr [rdi]
	cmp	r11, 8
	jae	.LBB0_126
# %bb.125:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm4, xmm4, xmm4
	xor	esi, esi
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_129
	.p2align	4, 0x90
.LBB0_123:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_131
	.p2align	4, 0x90
.LBB0_126:                              # %vector.ph1621
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, 9223372036854775792
	vmovapd	ymm2, ymmword ptr [rbx + 224]   # 32-byte Reload
	vmovapd	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	xor	ecx, ecx
	lea	rsi, [rax + 8]
	mov	rax, r8
	imul	rax, r14
	and	rsi, r11
	vmovapd	ymm0, ymm2
	vmovapd	ymm1, ymm3
	add	rax, r9
	add	rax, 32
	.p2align	4, 0x90
.LBB0_127:                              # %vector.body1626
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm4, ymmword ptr [rdx + 8*rcx]
	vmovupd	ymm5, ymmword ptr [rdx + 8*rcx + 32]
	vfmadd231pd	ymm0, ymm4, ymmword ptr [rax + 8*rcx - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rax + 8*rcx] # ymm1 = (ymm5 * mem) + ymm1
	add	rcx, 8
	vfmadd231pd	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rsi, rcx
	jne	.LBB0_127
# %bb.128:                              # %middle.block1618
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm0, ymm1, ymm0
	cmp	r11, rsi
	vextractf128	xmm1, ymm2, 1
	vaddpd	xmm1, xmm2, xmm1
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm6, xmm1, xmm2
	vaddsd	xmm4, xmm0, xmm3
	je	.LBB0_131
.LBB0_129:                              # %scalar.ph1619
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r9, r8
	.p2align	4, 0x90
.LBB0_130:                              # %L619
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rdx + 8*rsi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm4, xmm0, qword ptr [r9 + 8*rsi] # xmm4 = (xmm0 * mem) + xmm4
	add	rsi, 1
	vfmadd231sd	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r11, rsi
	jne	.LBB0_130
.LBB0_131:                              # %L647
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm2, xmm6, xmm6
	vucomisd	xmm2, xmm2
	jp	.LBB0_132
.LBB0_133:                              # %L654
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm15, xmm14
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	jne	.LBB0_139
	jp	.LBB0_139
# %bb.134:                              # %L656
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_139
# %bb.135:                              # %L669.preheader
                                        #   in Loop: Header=BB0_108 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_221
# %bb.136:                              # %ib330.us.preheader
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, rax
	xor	edx, edx
	imul	rcx, r14
	add	rcx, qword ptr [rdi]
	.p2align	4, 0x90
.LBB0_137:                              # %ib330.us
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm14
	jne	.LBB0_242
	jp	.LBB0_242
# %bb.138:                              # %L675.us
                                        #   in Loop: Header=BB0_137 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_137
.LBB0_139:                              # %L695
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm0, xmm15, xmm15
	vucomisd	xmm0, xmm0
	jp	.LBB0_249
# %bb.140:                              # %L700
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r10 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_243
# %bb.141:                              # %L714
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_142
# %bb.143:                              # %L719
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [r10]
	mov	rcx, qword ptr [rcx]
	vmovsd	xmm0, qword ptr [rcx + 8*rax - 8] # xmm0 = mem[0],zero
	jmp	.LBB0_144
	.p2align	4, 0x90
.LBB0_142:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm0, xmm0, xmm0
.LBB0_144:                              # %L724
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm15, xmm14
	vmovsd	qword ptr [rbx + 64], xmm0      # 8-byte Spill
	jne	.LBB0_146
	jnp	.LBB0_145
.LBB0_146:                              # %L728
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm10, xmm10, xmm10
	vcvtsi2sd	xmm1, xmm10, rax
	vmulsd	xmm3, xmm1, qword ptr [rsi]
	vucomisd	xmm15, xmm3
	jb	.LBB0_174
# %bb.147:                              # %L728
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm2, xmm2
	jp	.LBB0_174
# %bb.148:                              # %L728
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm6, xmm3
	jb	.LBB0_174
# %bb.149:                              # %L747
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm14, xmm15
	ja	.LBB0_244
# %bb.150:                              # %L753
                                        #   in Loop: Header=BB0_108 Depth=1
	vsqrtsd	xmm1, xmm15, xmm15
	mov	rsi, qword ptr [rbx + 32]       # 8-byte Reload
	vxorpd	xmm0, xmm0, xmm0
	vmovsd	xmm2, qword ptr [rsi + 8]       # xmm2 = mem[0],zero
	vucomisd	xmm2, xmm1
	jae	.LBB0_175
# %bb.151:                              # %L758
                                        #   in Loop: Header=BB0_108 Depth=1
	vdivsd	xmm5, xmm4, xmm15
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm0, xmm4, xmm5
	vmulsd	xmm4, xmm6, qword ptr [rsi]
	vsubsd	xmm0, xmm6, xmm0
	vucomisd	xmm4, xmm0
	jbe	.LBB0_164
# %bb.152:                              # %L765
                                        #   in Loop: Header=BB0_108 Depth=1
	test	rax, rax
	je	.LBB0_153
# %bb.154:                              # %L779.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	cmp	rax, 16
	mov	r9, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	jae	.LBB0_156
# %bb.155:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_159
	.p2align	4, 0x90
.LBB0_145:                              # %L726
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 184]      # 8-byte Reload
	mov	rsi, r15
	movabs	rax, offset j__coordinate_minimizer_726
	mov	qword ptr [rbx + 120], r13
	vmovsd	qword ptr [rbx + 48], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 48]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_175
	.p2align	4, 0x90
.LBB0_174:                              # %L923
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r15
	movabs	rax, offset j__sqrt_offrange_step_732
	mov	qword ptr [rbx + 120], r13
	vmovsd	qword ptr [rbx + 48], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 48]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
.LBB0_175:                              # %L926
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_176
# %bb.179:                              # %idxend367
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm1, xmm0, qword ptr [rbx + 64] # 8-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovsd	qword ptr [rax + 8*r15 - 8], xmm15
	vucomisd	xmm1, xmm14
	jne	.LBB0_180
	jnp	.LBB0_200
.LBB0_180:                              # %L934
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r10 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_248
# %bb.181:                              # %L948
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_186
# %bb.182:                              # %L953
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [r10]
	mov	rcx, qword ptr [rcx]
	vmovsd	qword ptr [rcx + 8*rax - 8], xmm0
	jmp	.LBB0_183
	.p2align	4, 0x90
.LBB0_186:                              # %L956
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm0, xmm14
	jne	.LBB0_187
	jnp	.LBB0_183
.LBB0_187:                              # %L959
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdx, qword ptr [r10 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r10 + 24], rax
	mov	rdi, qword ptr [r10]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_188
# %bb.227:                              # %idxend423
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovsd	qword ptr [rsi + 8*rdx], xmm0
	mov	rdi, qword ptr [r10 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_228
# %bb.232:                              # %idxend443
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r15
	mov	qword ptr [rcx + 8*r15 - 8], rax
	.p2align	4, 0x90
.LBB0_183:                              # %L973
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_200
# %bb.184:                              # %L986.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	cmp	rax, 16
	mov	r9, qword ptr [rdx]
	mov	r8, qword ptr [rdx + 24]
	jae	.LBB0_191
# %bb.185:                              #   in Loop: Header=BB0_108 Depth=1
	xor	edi, edi
	jmp	.LBB0_197
.LBB0_191:                              # %vector.memcheck1545
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdx, qword ptr [rbx + 24]       # 8-byte Reload
	lea	rdx, [8*rdx]
	imul	rdx, r8
	add	rdx, r9
	lea	rsi, [rdx + 8*rax]
	cmp	rsi, rcx
	jbe	.LBB0_194
# %bb.192:                              # %vector.memcheck1545
                                        #   in Loop: Header=BB0_108 Depth=1
	lea	rsi, [rcx + 8*rax]
	cmp	rdx, rsi
	jae	.LBB0_194
# %bb.193:                              #   in Loop: Header=BB0_108 Depth=1
	xor	edi, edi
	jmp	.LBB0_197
.LBB0_194:                              # %vector.ph1559
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastsd	ymm0, xmm1
	and	rdi, rdx
	mov	rdx, r8
	imul	rdx, r14
	lea	rsi, [r9 + rdx + 96]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_195:                              # %vector.body1564
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulpd	ymm3, ymm0, ymmword ptr [rsi + 8*rdx - 64]
	vmulpd	ymm2, ymm0, ymmword ptr [rsi + 8*rdx - 96]
	vmulpd	ymm4, ymm0, ymmword ptr [rsi + 8*rdx - 32]
	vmulpd	ymm5, ymm0, ymmword ptr [rsi + 8*rdx]
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx + 32]
	vmovupd	ymm6, ymmword ptr [rcx + 8*rdx]
	vmovupd	ymm8, ymmword ptr [rcx + 8*rdx + 64]
	vsubpd	ymm3, ymm7, ymm3
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx + 96]
	vsubpd	ymm2, ymm6, ymm2
	vsubpd	ymm4, ymm8, ymm4
	vsubpd	ymm5, ymm7, ymm5
	vmovupd	ymmword ptr [rcx + 8*rdx], ymm2
	vmovupd	ymmword ptr [rcx + 8*rdx + 32], ymm3
	vmovupd	ymmword ptr [rcx + 8*rdx + 64], ymm4
	vmovupd	ymmword ptr [rcx + 8*rdx + 96], ymm5
	add	rdx, 16
	cmp	rdi, rdx
	jne	.LBB0_195
# %bb.196:                              # %middle.block1556
                                        #   in Loop: Header=BB0_108 Depth=1
	cmp	rax, rdi
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
	je	.LBB0_200
	.p2align	4, 0x90
.LBB0_197:                              # %scalar.ph1557
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r9, r8
	.p2align	4, 0x90
.LBB0_198:                              # %L986
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm0, xmm1, qword ptr [r9 + 8*rdi]
	vmovsd	xmm2, qword ptr [rcx + 8*rdi]   # xmm2 = mem[0],zero
	vsubsd	xmm0, xmm2, xmm0
	vmovsd	qword ptr [rcx + 8*rdi], xmm0
	add	rdi, 1
	cmp	rax, rdi
	jne	.LBB0_198
# %bb.199:                              #   in Loop: Header=BB0_108 Depth=1
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
.LBB0_200:                              # %L1010
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_7
	test	byte ptr [rbx + 140], 1         # 1-byte Folded Reload
	vandpd	xmm2, xmm1, xmmword ptr [rax]
	je	.LBB0_203
# %bb.201:                              # %L1010
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm1, xmm14
	jne	.LBB0_202
	jnp	.LBB0_203
.LBB0_202:                              # %L1016
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r10
	mov	rdx, r15
	vmovapd	xmmword ptr [rbx + 64], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_727
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovapd	xmm2, xmmword ptr [rbx + 64]    # 16-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	vmulsd	xmm2, xmm2, xmm0
.LBB0_203:                              # %L1021
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm0, xmm2, xmm2
	vucomisd	xmm0, xmm0
	jp	.LBB0_250
# %bb.204:                              # %L1030
                                        #   in Loop: Header=BB0_108 Depth=1
	vmovsd	xmm0, qword ptr [rbx + 176]     # 8-byte Reload
                                        # xmm0 = mem[0],zero
	add	qword ptr [rbx + 24], 1         # 8-byte Folded Spill
	add	r14, 8
	cmp	r15, qword ptr [rbx + 152]      # 8-byte Folded Reload
	lea	r15, [r15 + 1]
	vmaxsd	xmm0, xmm2, xmm0
	jne	.LBB0_108
	jmp	.LBB0_205
.LBB0_153:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_161
.LBB0_156:                              # %vector.ph1586
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastsd	ymm4, xmm5
	and	rsi, rdx
	movabs	rdx, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rdx]
	mov	rdx, r8
	imul	rdx, r14
	vmovapd	ymm7, ymm0
	vmovapd	ymm8, ymm0
	lea	rdi, [r9 + rdx + 96]
	movabs	rdx, offset .LCPI0_1
	vmovapd	ymm6, ymmword ptr [rdx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_157:                              # %vector.body1591
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulpd	ymm9, ymm4, ymmword ptr [rdi + 8*rdx - 96]
	vmulpd	ymm10, ymm4, ymmword ptr [rdi + 8*rdx - 64]
	vmulpd	ymm11, ymm4, ymmword ptr [rdi + 8*rdx - 32]
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdx]
	vmulpd	ymm12, ymm4, ymmword ptr [rdi + 8*rdx]
	vsubpd	ymm9, ymm13, ymm9
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdx + 32]
	vsubpd	ymm10, ymm13, ymm10
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdx + 64]
	vfmadd231pd	ymm6, ymm9, ymm9        # ymm6 = (ymm9 * ymm9) + ymm6
	vsubpd	ymm11, ymm13, ymm11
	vmovupd	ymm13, ymmword ptr [rcx + 8*rdx + 96]
	add	rdx, 16
	vfmadd231pd	ymm0, ymm10, ymm10      # ymm0 = (ymm10 * ymm10) + ymm0
	cmp	rsi, rdx
	vsubpd	ymm12, ymm13, ymm12
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	jne	.LBB0_157
# %bb.158:                              # %middle.block1583
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddpd	ymm0, ymm0, ymm6
	cmp	rax, rsi
	vaddpd	ymm0, ymm7, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm4, ymm0, 1
	vaddpd	xmm0, xmm0, xmm4
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm4
	je	.LBB0_161
.LBB0_159:                              # %scalar.ph1584
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r9, r8
	.p2align	4, 0x90
.LBB0_160:                              # %L779
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm4, xmm5, qword ptr [r9 + 8*rsi]
	vmovsd	xmm6, qword ptr [rcx + 8*rsi]   # xmm6 = mem[0],zero
	add	rsi, 1
	cmp	rax, rsi
	vsubsd	xmm4, xmm6, xmm4
	vfmadd231sd	xmm0, xmm4, xmm4        # xmm0 = (xmm4 * xmm4) + xmm0
	jne	.LBB0_160
.LBB0_161:                              # %L802
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm0, xmm3
	jb	.LBB0_163
# %bb.162:                              # %L802
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm3, xmm0, xmm0
	vucomisd	xmm3, xmm3
	jp	.LBB0_163
.LBB0_164:                              # %L813
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm14, xmm0
	ja	.LBB0_245
# %bb.165:                              # %L818
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubsd	xmm3, xmm1, xmm2
	vucomisd	xmm14, xmm3
	ja	.LBB0_246
# %bb.166:                              # %L825
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddsd	xmm4, xmm1, xmm2
	vucomisd	xmm14, xmm4
	ja	.LBB0_247
# %bb.167:                              # %L832
                                        #   in Loop: Header=BB0_108 Depth=1
	vsqrtsd	xmm6, xmm3, xmm3
	vsqrtsd	xmm4, xmm4, xmm4
	vsqrtsd	xmm3, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vmulsd	xmm0, xmm6, xmm4
	vmulsd	xmm4, xmm1, xmm0
	vaddsd	xmm0, xmm5, qword ptr [rbx + 64] # 8-byte Folded Reload
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_173
# %bb.168:                              # %L832
                                        #   in Loop: Header=BB0_108 Depth=1
	vdivsd	xmm4, xmm3, xmm4
	movabs	rax, offset .LCPI0_4
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_173
# %bb.169:                              # %L832
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovsd	xmm5, qword ptr [rax]           # xmm5 = mem[0],zero
	vucomisd	xmm5, xmm4
	jb	.LBB0_173
# %bb.170:                              # %L832
                                        #   in Loop: Header=BB0_108 Depth=1
	vmulsd	xmm4, xmm2, xmm4
	movabs	rax, offset .LCPI0_4
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_173
# %bb.171:                              # %L832
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomisd	xmm5, xmm4
	jb	.LBB0_173
# %bb.172:                              # %L866
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm1, xmm4, xmmword ptr [rax]
	vmaxsd	xmm1, xmm0, xmm1
	vminsd	xmm1, xmm1, xmm4
	vsubsd	xmm0, xmm0, xmm1
	vaddsd	xmm0, xmm14, xmm0
	jmp	.LBB0_175
.LBB0_173:                              # %L921
                                        #   in Loop: Header=BB0_108 Depth=1
	xor	edi, edi
	movabs	rax, offset j__sqrt_band_step_731
	mov	qword ptr [rbx + 120], r13
	vmovsd	qword ptr [rbx + 48], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 48]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_175
.LBB0_163:                              # %L811
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 64]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r15
	movabs	rax, offset j__sqrt_offrange_step_732
	mov	qword ptr [rbx + 120], r13
	vmovsd	qword ptr [rbx + 48], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 48]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_175
.LBB0_113:                              # %L563
                                        #   in Loop: Header=BB0_108 Depth=1
	test	r11, r11
	je	.LBB0_114
# %bb.115:                              # %L577.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	r9, qword ptr [rax]
	mov	r8, qword ptr [rax + 24]
	mov	r10, qword ptr [rdi]
	cmp	r11, 8
	jae	.LBB0_117
# %bb.116:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm15, xmm15, xmm15
	xor	esi, esi
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_120
.LBB0_132:                              # %L652
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, r15
	movabs	rax, offset j__check_residual_734
	mov	qword ptr [rbx + 120], r13
	mov	qword ptr [rbx + 112], rdi
	vmovsd	qword ptr [rbx + 48], xmm15     # 8-byte Spill
	vmovsd	qword ptr [rbx + 64], xmm6      # 8-byte Spill
	vmovsd	qword ptr [rbx + 168], xmm4     # 8-byte Spill
	vmovsd	qword ptr [rbx + 160], xmm2     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm2, qword ptr [rbx + 160]     # 8-byte Reload
                                        # xmm2 = mem[0],zero
	vmovsd	xmm4, qword ptr [rbx + 168]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vmovsd	xmm6, qword ptr [rbx + 64]      # 8-byte Reload
                                        # xmm6 = mem[0],zero
	vmovsd	xmm15, qword ptr [rbx + 48]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_133
.LBB0_114:                              #   in Loop: Header=BB0_108 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm15, xmm15, xmm15
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_131
.LBB0_117:                              # %vector.ph1644
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, 9223372036854775792
	xor	edx, edx
	lea	rsi, [rax + 8]
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	mov	rax, r8
	and	rsi, r11
	imul	rax, r14
	vmovapd	ymm3, ymm0
	vmovapd	ymm5, ymm0
	lea	rcx, [r9 + rax + 32]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	vmovapd	ymm2, ymm1
	vmovapd	ymm4, ymm1
.LBB0_118:                              # %vector.body1649
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm6, ymmword ptr [rcx + 8*rdx - 32]
	vmovupd	ymm8, ymmword ptr [r10 + 8*rdx]
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx]
	vmovupd	ymm9, ymmword ptr [r10 + 8*rdx + 32]
	add	rdx, 8
	cmp	rsi, rdx
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm7        # ymm3 = (ymm9 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
	jne	.LBB0_118
# %bb.119:                              # %middle.block1641
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm4, ymm5, ymm4
	vaddpd	ymm0, ymm0, ymm1
	cmp	r11, rsi
	vxorpd	xmm14, xmm14, xmm14
	vextractf128	xmm1, ymm4, 1
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm1, xmm4, xmm1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm6, xmm1, xmm3
	vpermilpd	xmm1, xmm2, 1           # xmm1 = xmm2[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm4, xmm2, xmm1
	vaddsd	xmm15, xmm0, xmm3
	je	.LBB0_131
.LBB0_120:                              # %scalar.ph1642
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r9, r8
.LBB0_121:                              # %L577
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [r9 + 8*rsi]    # xmm0 = mem[0],zero
	vmovsd	xmm1, qword ptr [r10 + 8*rsi]   # xmm1 = mem[0],zero
	add	rsi, 1
	cmp	r11, rsi
	vfmadd231sd	xmm15, xmm0, xmm0       # xmm15 = (xmm0 * xmm0) + xmm15
	vfmadd231sd	xmm4, xmm1, xmm0        # xmm4 = (xmm1 * xmm0) + xmm4
	vfmadd231sd	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_121
	jmp	.LBB0_131
.LBB0_1:                                # %L4
	mov	r14, qword ptr [r15]
	mov	rdi, qword ptr [rcx + 8]
	movabs	rax, offset "j__shuffle!_724"
	mov	qword ptr [rbx + 144], rdx      # 8-byte Spill
	mov	rsi, r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	test	r14, r14
	mov	qword ptr [rbx + 64], rax       # 8-byte Spill
	jle	.LBB0_2
# %bb.3:                                # %L4
	mov	rax, qword ptr [r15]
	test	rax, rax
	jle	.LBB0_5
.LBB0_6:                                # %L22.preheader
	movabs	rcx, offset .LCPI0_0
	vxorpd	xmm14, xmm14, xmm14
	mov	r14d, 1
	mov	qword ptr [rbx + 152], rax      # 8-byte Spill
	vbroadcastsd	ymm0, qword ptr [rcx]
	movabs	rcx, offset .LCPI0_1
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovapd	ymm0, ymmword ptr [rcx]
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vmovapd	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_7:                                # %L22
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_17 Depth 2
                                        #     Child Loop BB0_20 Depth 2
                                        #     Child Loop BB0_26 Depth 2
                                        #     Child Loop BB0_29 Depth 2
                                        #     Child Loop BB0_36 Depth 2
                                        #     Child Loop BB0_56 Depth 2
                                        #     Child Loop BB0_59 Depth 2
                                        #     Child Loop BB0_94 Depth 2
                                        #     Child Loop BB0_97 Depth 2
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rax, qword ptr [rax]
	mov	r13, qword ptr [rcx]
	mov	r15, qword ptr [rax + 8*r14 - 8]
	mov	rdi, qword ptr [r13 + 32]
	lea	r12, [r15 - 1]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_8
# %bb.11:                               # %idxend
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovsd	qword ptr [rbx + 176], xmm0     # 8-byte Spill
	vmovsd	xmm15, qword ptr [rax + 8*r15 - 8] # xmm15 = mem[0],zero
	mov	rax, qword ptr [r13]
	mov	r11, qword ptr [rdi + 8]
	vucomisd	xmm15, xmm15
	jp	.LBB0_12
# %bb.21:                               # %L86
                                        #   in Loop: Header=BB0_7 Depth=1
	test	r11, r11
	je	.LBB0_22
# %bb.23:                               # %L99.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_25
# %bb.24:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm4, xmm4, xmm4
	xor	edx, edx
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_28
	.p2align	4, 0x90
.LBB0_22:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_30
	.p2align	4, 0x90
.LBB0_25:                               # %vector.ph1498
                                        #   in Loop: Header=BB0_7 Depth=1
	vmovapd	ymm2, ymmword ptr [rbx + 224]   # 32-byte Reload
	vmovapd	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	movabs	rax, 9223372036854775792
	lea	rsi, [r8 + 8*r9 + 32]
	lea	rdx, [rax + 8]
	xor	eax, eax
	and	rdx, r11
	vmovapd	ymm0, ymm2
	vmovapd	ymm1, ymm3
	.p2align	4, 0x90
.LBB0_26:                               # %vector.body1503
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm4, ymmword ptr [rcx + 8*rax]
	vmovupd	ymm5, ymmword ptr [rcx + 8*rax + 32]
	vfmadd231pd	ymm0, ymm4, ymmword ptr [rsi + 8*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rsi + 8*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 8
	vfmadd231pd	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_26
# %bb.27:                               # %middle.block1495
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm0, ymm1, ymm0
	cmp	r11, rdx
	vextractf128	xmm1, ymm2, 1
	vaddpd	xmm1, xmm2, xmm1
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm6, xmm1, xmm2
	vaddsd	xmm4, xmm0, xmm3
	je	.LBB0_30
.LBB0_28:                               # %scalar.ph1496
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rax, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_29:                               # %L99
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm4, xmm0, qword ptr [rax + 8*rdx] # xmm4 = (xmm0 * mem) + xmm4
	add	rdx, 1
	vfmadd231sd	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r11, rdx
	jne	.LBB0_29
.LBB0_30:                               # %L127
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm2, xmm6, xmm6
	vucomisd	xmm2, xmm2
	jp	.LBB0_31
.LBB0_32:                               # %L134
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm15, xmm14
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	jne	.LBB0_38
	jp	.LBB0_38
# %bb.33:                               # %L136
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_38
# %bb.34:                               # %L149.preheader
                                        #   in Loop: Header=BB0_7 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_208
# %bb.35:                               # %ib.us.preheader
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 8*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_36:                               # %ib.us
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm14
	jne	.LBB0_233
	jp	.LBB0_233
# %bb.37:                               # %L155.us
                                        #   in Loop: Header=BB0_36 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_36
.LBB0_38:                               # %L175
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm0, xmm15, xmm15
	vucomisd	xmm0, xmm0
	jp	.LBB0_240
# %bb.39:                               # %L180
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r10 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_234
# %bb.40:                               # %L194
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_41
# %bb.42:                               # %L199
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r10]
	mov	rcx, qword ptr [rcx]
	vmovsd	xmm0, qword ptr [rcx + 8*rax - 8] # xmm0 = mem[0],zero
	jmp	.LBB0_43
	.p2align	4, 0x90
.LBB0_41:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm0, xmm0, xmm0
.LBB0_43:                               # %L204
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm15, xmm14
	vmovsd	qword ptr [rbx + 48], xmm0      # 8-byte Spill
	jne	.LBB0_45
	jnp	.LBB0_44
.LBB0_45:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm10, xmm10, xmm10
	vcvtsi2sd	xmm1, xmm10, rax
	vmulsd	xmm3, xmm1, qword ptr [rsi]
	vucomisd	xmm15, xmm3
	jb	.LBB0_73
# %bb.46:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm2, xmm2
	jp	.LBB0_73
# %bb.47:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm6, xmm3
	jb	.LBB0_73
# %bb.48:                               # %L227
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm14, xmm15
	ja	.LBB0_235
# %bb.49:                               # %L233
                                        #   in Loop: Header=BB0_7 Depth=1
	vsqrtsd	xmm1, xmm15, xmm15
	mov	rsi, qword ptr [rbx + 32]       # 8-byte Reload
	vxorpd	xmm0, xmm0, xmm0
	vmovsd	xmm2, qword ptr [rsi + 8]       # xmm2 = mem[0],zero
	vucomisd	xmm2, xmm1
	jae	.LBB0_74
# %bb.50:                               # %L238
                                        #   in Loop: Header=BB0_7 Depth=1
	vdivsd	xmm5, xmm4, xmm15
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm0, xmm4, xmm5
	vmulsd	xmm4, xmm6, qword ptr [rsi]
	vsubsd	xmm0, xmm6, xmm0
	vucomisd	xmm4, xmm0
	jbe	.LBB0_63
# %bb.51:                               # %L245
                                        #   in Loop: Header=BB0_7 Depth=1
	test	rax, rax
	je	.LBB0_52
# %bb.53:                               # %L259.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_55
# %bb.54:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_58
	.p2align	4, 0x90
.LBB0_44:                               # %L206
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 184]      # 8-byte Reload
	mov	rsi, r15
	vmovsd	qword ptr [rbx + 24], xmm15     # 8-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__coordinate_minimizer_726
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 24]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_74
	.p2align	4, 0x90
.LBB0_73:                               # %L403
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r15
	vmovsd	qword ptr [rbx + 24], xmm15     # 8-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_732
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 24]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
.LBB0_74:                               # %L406
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_75
# %bb.78:                               # %idxend91
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm1, xmm0, qword ptr [rbx + 48] # 8-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovsd	qword ptr [rax + 8*r15 - 8], xmm15
	vucomisd	xmm1, xmm14
	jne	.LBB0_79
	jnp	.LBB0_99
.LBB0_79:                               # %L414
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r10 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_239
# %bb.80:                               # %L428
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_85
# %bb.81:                               # %L433
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r10]
	mov	rcx, qword ptr [rcx]
	vmovsd	qword ptr [rcx + 8*rax - 8], xmm0
	jmp	.LBB0_82
	.p2align	4, 0x90
.LBB0_85:                               # %L436
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm0, xmm14
	jne	.LBB0_86
	jnp	.LBB0_82
.LBB0_86:                               # %L439
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdx, qword ptr [r10 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r10 + 24], rax
	mov	rdi, qword ptr [r10]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_87
# %bb.214:                              # %idxend149
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovsd	qword ptr [rsi + 8*rdx], xmm0
	mov	rdi, qword ptr [r10 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_215
# %bb.219:                              # %idxend169
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r15
	mov	qword ptr [rcx + 8*r15 - 8], rax
	.p2align	4, 0x90
.LBB0_82:                               # %L453
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_99
# %bb.83:                               # %L466.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 16
	jae	.LBB0_90
# %bb.84:                               #   in Loop: Header=BB0_7 Depth=1
	xor	esi, esi
	jmp	.LBB0_96
.LBB0_90:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 8*rdx]
	cmp	rcx, rdx
	jae	.LBB0_93
# %bb.91:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [rcx + 8*rax]
	lea	rsi, [r8 + 8*r12]
	cmp	rsi, rdx
	jae	.LBB0_93
# %bb.92:                               #   in Loop: Header=BB0_7 Depth=1
	xor	esi, esi
	jmp	.LBB0_96
.LBB0_93:                               # %vector.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastsd	ymm0, xmm1
	lea	rdi, [r8 + 8*r12 + 96]
	and	rsi, rdx
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_94:                               # %vector.body
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulpd	ymm3, ymm0, ymmword ptr [rdi + 8*rdx - 64]
	vmulpd	ymm2, ymm0, ymmword ptr [rdi + 8*rdx - 96]
	vmulpd	ymm4, ymm0, ymmword ptr [rdi + 8*rdx - 32]
	vmulpd	ymm5, ymm0, ymmword ptr [rdi + 8*rdx]
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx + 32]
	vmovupd	ymm6, ymmword ptr [rcx + 8*rdx]
	vmovupd	ymm8, ymmword ptr [rcx + 8*rdx + 64]
	vsubpd	ymm3, ymm7, ymm3
	vmovupd	ymm7, ymmword ptr [rcx + 8*rdx + 96]
	vsubpd	ymm2, ymm6, ymm2
	vsubpd	ymm4, ymm8, ymm4
	vsubpd	ymm5, ymm7, ymm5
	vmovupd	ymmword ptr [rcx + 8*rdx], ymm2
	vmovupd	ymmword ptr [rcx + 8*rdx + 32], ymm3
	vmovupd	ymmword ptr [rcx + 8*rdx + 64], ymm4
	vmovupd	ymmword ptr [rcx + 8*rdx + 96], ymm5
	add	rdx, 16
	cmp	rsi, rdx
	jne	.LBB0_94
# %bb.95:                               # %middle.block
                                        #   in Loop: Header=BB0_7 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
	je	.LBB0_99
	.p2align	4, 0x90
.LBB0_96:                               # %scalar.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [r8 + 8*r12]
	.p2align	4, 0x90
.LBB0_97:                               # %L466
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm0, xmm1, qword ptr [rdx + 8*rsi]
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm0, xmm2, xmm0
	vmovsd	qword ptr [rcx + 8*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_97
# %bb.98:                               #   in Loop: Header=BB0_7 Depth=1
	mov	qword ptr [rbx + 80], r15       # 8-byte Spill
.LBB0_99:                               # %L490
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rax, offset .LCPI0_7
	test	byte ptr [rbx + 140], 1         # 1-byte Folded Reload
	vandpd	xmm2, xmm1, xmmword ptr [rax]
	je	.LBB0_102
# %bb.100:                              # %L490
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm1, xmm14
	jne	.LBB0_101
	jnp	.LBB0_102
.LBB0_101:                              # %L496
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rsi, r10
	mov	rdx, r15
	vmovapd	xmmword ptr [rbx + 48], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_727
	mov	qword ptr [rbx + 120], rcx
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovapd	xmm2, xmmword ptr [rbx + 48]    # 16-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	vmulsd	xmm2, xmm2, xmm0
.LBB0_102:                              # %L501
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm0, xmm2, xmm2
	vucomisd	xmm0, xmm0
	jp	.LBB0_241
# %bb.103:                              # %L510
                                        #   in Loop: Header=BB0_7 Depth=1
	vmovsd	xmm0, qword ptr [rbx + 176]     # 8-byte Reload
                                        # xmm0 = mem[0],zero
	cmp	r14, qword ptr [rbx + 152]      # 8-byte Folded Reload
	lea	r14, [r14 + 1]
	vmaxsd	xmm0, xmm2, xmm0
	jne	.LBB0_7
	jmp	.LBB0_104
.LBB0_52:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_60
.LBB0_55:                               # %vector.ph1466
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rdx, offset .LCPI0_0
	movabs	rsi, 9223372036854775792
	vbroadcastsd	ymm6, xmm5
	lea	rdi, [r8 + 8*r9 + 96]
	vbroadcastsd	ymm0, qword ptr [rdx]
	mov	rdx, rax
	and	rdx, rsi
	movabs	rsi, offset .LCPI0_1
	vmovapd	ymm4, ymmword ptr [rsi]
	xor	esi, esi
	vmovapd	ymm7, ymm0
	vmovapd	ymm8, ymm0
	.p2align	4, 0x90
.LBB0_56:                               # %vector.body1471
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulpd	ymm9, ymm6, ymmword ptr [rdi + 8*rsi - 96]
	vmulpd	ymm10, ymm6, ymmword ptr [rdi + 8*rsi - 64]
	vmulpd	ymm11, ymm6, ymmword ptr [rdi + 8*rsi - 32]
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi]
	vmulpd	ymm12, ymm6, ymmword ptr [rdi + 8*rsi]
	vsubpd	ymm9, ymm13, ymm9
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi + 32]
	vsubpd	ymm10, ymm13, ymm10
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi + 64]
	vfmadd231pd	ymm4, ymm9, ymm9        # ymm4 = (ymm9 * ymm9) + ymm4
	vsubpd	ymm11, ymm13, ymm11
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi + 96]
	add	rsi, 16
	vfmadd231pd	ymm0, ymm10, ymm10      # ymm0 = (ymm10 * ymm10) + ymm0
	cmp	rdx, rsi
	vsubpd	ymm12, ymm13, ymm12
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	jne	.LBB0_56
# %bb.57:                               # %middle.block1463
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddpd	ymm0, ymm0, ymm4
	cmp	rax, rdx
	vaddpd	ymm0, ymm7, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm4, ymm0, 1
	vaddpd	xmm0, xmm0, xmm4
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm4
	je	.LBB0_60
.LBB0_58:                               # %scalar.ph1464
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rsi, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_59:                               # %L259
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm4, xmm5, qword ptr [rsi + 8*rdx]
	vmovsd	xmm6, qword ptr [rcx + 8*rdx]   # xmm6 = mem[0],zero
	add	rdx, 1
	cmp	rax, rdx
	vsubsd	xmm4, xmm6, xmm4
	vfmadd231sd	xmm0, xmm4, xmm4        # xmm0 = (xmm4 * xmm4) + xmm0
	jne	.LBB0_59
.LBB0_60:                               # %L282
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm0, xmm3
	jb	.LBB0_62
# %bb.61:                               # %L282
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm3, xmm0, xmm0
	vucomisd	xmm3, xmm3
	jp	.LBB0_62
.LBB0_63:                               # %L293
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm14, xmm0
	ja	.LBB0_236
# %bb.64:                               # %L298
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubsd	xmm3, xmm1, xmm2
	movabs	rax, offset .LCPI0_4
	vucomisd	xmm14, xmm3
	ja	.LBB0_237
# %bb.65:                               # %L305
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddsd	xmm4, xmm1, xmm2
	vucomisd	xmm14, xmm4
	ja	.LBB0_238
# %bb.66:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vsqrtsd	xmm6, xmm3, xmm3
	vsqrtsd	xmm4, xmm4, xmm4
	vsqrtsd	xmm3, xmm0, xmm0
	vmulsd	xmm0, xmm6, xmm4
	vmulsd	xmm4, xmm1, xmm0
	vaddsd	xmm0, xmm5, qword ptr [rbx + 48] # 8-byte Folded Reload
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_72
# %bb.67:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vdivsd	xmm4, xmm3, xmm4
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_72
# %bb.68:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rcx, offset .LCPI0_5
	vmovsd	xmm5, qword ptr [rcx]           # xmm5 = mem[0],zero
	vucomisd	xmm5, xmm4
	jb	.LBB0_72
# %bb.69:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vmulsd	xmm4, xmm2, xmm4
	vucomisd	xmm4, qword ptr [rax]
	jb	.LBB0_72
# %bb.70:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomisd	xmm5, xmm4
	jb	.LBB0_72
# %bb.71:                               # %L346
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm1, xmm4, xmmword ptr [rax]
	vmaxsd	xmm1, xmm0, xmm1
	vminsd	xmm1, xmm1, xmm4
	vsubsd	xmm0, xmm0, xmm1
	vaddsd	xmm0, xmm14, xmm0
	jmp	.LBB0_74
.LBB0_72:                               # %L401
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	xor	edi, edi
	vmovsd	qword ptr [rbx + 24], xmm15     # 8-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_band_step_731
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 24]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_74
.LBB0_62:                               # %L291
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 48]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r15
	vmovsd	qword ptr [rbx + 24], xmm15     # 8-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_732
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 24]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_74
.LBB0_12:                               # %L43
                                        #   in Loop: Header=BB0_7 Depth=1
	test	r11, r11
	je	.LBB0_13
# %bb.14:                               # %L57.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	r10, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_16
# %bb.15:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm15, xmm15, xmm15
	xor	edx, edx
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_19
.LBB0_31:                               # %L132
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rsi, r15
	vmovsd	qword ptr [rbx + 24], xmm15     # 8-byte Spill
	vmovsd	qword ptr [rbx + 48], xmm6      # 8-byte Spill
	vmovsd	qword ptr [rbx + 168], xmm4     # 8-byte Spill
	vmovsd	qword ptr [rbx + 160], xmm2     # 8-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__check_residual_734
	mov	qword ptr [rbx + 128], r13
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovsd	xmm2, qword ptr [rbx + 160]     # 8-byte Reload
                                        # xmm2 = mem[0],zero
	vmovsd	xmm4, qword ptr [rbx + 168]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vmovsd	xmm6, qword ptr [rbx + 48]      # 8-byte Reload
                                        # xmm6 = mem[0],zero
	vmovsd	xmm15, qword ptr [rbx + 24]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_32
.LBB0_13:                               #   in Loop: Header=BB0_7 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm15, xmm15, xmm15
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_30
.LBB0_16:                               # %vector.ph1521
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rax, offset .LCPI0_0
	movabs	rdx, 9223372036854775792
	lea	rsi, [r8 + 8*r9 + 32]
	xor	ecx, ecx
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	add	rdx, 8
	vmovapd	ymm1, ymmword ptr [rax]
	and	rdx, r11
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_17:                               # %vector.body1526
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm6, ymmword ptr [rsi + 8*rcx - 32]
	vmovupd	ymm8, ymmword ptr [r10 + 8*rcx]
	vmovupd	ymm7, ymmword ptr [rsi + 8*rcx]
	vmovupd	ymm9, ymmword ptr [r10 + 8*rcx + 32]
	add	rcx, 8
	cmp	rdx, rcx
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm7        # ymm3 = (ymm9 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
	jne	.LBB0_17
# %bb.18:                               # %middle.block1518
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddpd	ymm2, ymm3, ymm2
	vaddpd	ymm4, ymm5, ymm4
	vaddpd	ymm0, ymm0, ymm1
	cmp	r11, rdx
	vxorpd	xmm14, xmm14, xmm14
	vextractf128	xmm1, ymm4, 1
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm1, xmm4, xmm1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm6, xmm1, xmm3
	vpermilpd	xmm1, xmm2, 1           # xmm1 = xmm2[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm4, xmm2, xmm1
	vaddsd	xmm15, xmm0, xmm3
	je	.LBB0_30
.LBB0_19:                               # %scalar.ph1519
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rax, [r8 + 8*r9]
.LBB0_20:                               # %L57
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rax + 8*rdx]   # xmm0 = mem[0],zero
	vmovsd	xmm1, qword ptr [r10 + 8*rdx]   # xmm1 = mem[0],zero
	add	rdx, 1
	cmp	r11, rdx
	vfmadd231sd	xmm15, xmm0, xmm0       # xmm15 = (xmm0 * xmm0) + xmm15
	vfmadd231sd	xmm4, xmm1, xmm0        # xmm4 = (xmm1 * xmm0) + xmm4
	vfmadd231sd	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_20
	jmp	.LBB0_30
.LBB0_205:                              # %L1045.loopexit
	mov	rax, qword ptr [rbx + 152]      # 8-byte Reload
	mov	rcx, qword ptr [rbx + 80]       # 8-byte Reload
	mov	rdx, qword ptr [rbx + 144]      # 8-byte Reload
	mov	qword ptr [rbx + 200], rax
	mov	qword ptr [rbx + 192], rcx
	jmp	.LBB0_206
.LBB0_104:                              # %L1045.loopexit691
	mov	rax, qword ptr [rbx + 80]       # 8-byte Reload
	mov	rdx, qword ptr [rbx + 144]      # 8-byte Reload
	mov	qword ptr [rbx + 216], r15
	mov	qword ptr [rbx + 208], rax
	jmp	.LBB0_206
.LBB0_2:
	xor	eax, eax
	test	rax, rax
	jg	.LBB0_6
.LBB0_5:
	mov	rdx, qword ptr [rbx + 144]      # 8-byte Reload
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_206
.LBB0_106:
	vxorpd	xmm0, xmm0, xmm0
.LBB0_206:                              # %L1045
	mov	rax, qword ptr [rbx + 104]
	mov	qword ptr [rdx], rax
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_242:                              # %L691.split.us
	movabs	rax, 135794567260688
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 88]
	mov	edx, 1
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_233:                              # %L171.split.us
	movabs	rax, 135794567260688
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 88]
	mov	edx, 1
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_109:                              # %oob282
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_220
.LBB0_111:                              # %oob282
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_111
.LBB0_220:                              # %oob282
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_249:                              # %L1008
	movabs	rax, offset j__refuse_curvature_733
	mov	rdi, r15
	vzeroupper
	call	rax
.LBB0_243:                              # %L711
	movabs	rax, offset j_throw_boundserror_728
	lea	rsi, [rbx + 200]
	mov	qword ptr [rbx + 200], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_176:                              # %oob365
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_225
.LBB0_178:                              # %oob365
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_178
.LBB0_225:                              # %oob365
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_250:                              # %L1027
	movabs	rax, 135794568219280
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 88]
	mov	edx, 1
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_8:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_207
.LBB0_10:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_10
.LBB0_207:                              # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_240:                              # %L488
	movabs	rax, offset j__refuse_curvature_733
	mov	rdi, r15
	vzeroupper
	call	rax
.LBB0_234:                              # %L191
	movabs	rax, offset j_throw_boundserror_728
	lea	rsi, [rbx + 216]
	mov	qword ptr [rbx + 216], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_75:                               # %oob89
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_212
.LBB0_77:                               # %oob89
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_77
.LBB0_212:                              # %oob89
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_241:                              # %L507
	movabs	rax, 135794568219280
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 88]
	mov	edx, 1
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_248:                              # %L945
	movabs	rax, offset j_throw_boundserror_728
	lea	rsi, [rbx + 192]
	mov	qword ptr [rbx + 192], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_239:                              # %L425
	movabs	rax, offset j_throw_boundserror_728
	lea	rsi, [rbx + 208]
	mov	qword ptr [rbx + 208], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_244:                              # %L751
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm15
	vzeroupper
	call	rax
.LBB0_235:                              # %L231
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm15
	vzeroupper
	call	rax
.LBB0_221:                              # %oob335
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_224
.LBB0_223:                              # %oob335
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_223
.LBB0_224:                              # %oob335
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r15
	vzeroupper
	call	rax
.LBB0_208:                              # %oob60
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_211
.LBB0_210:                              # %oob60
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_210
.LBB0_211:                              # %oob60
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r15
	vzeroupper
	call	rax
.LBB0_245:                              # %L816
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_246:                              # %L823
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_247:                              # %L830
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_236:                              # %L296
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_237:                              # %L303
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_238:                              # %L310
	movabs	rax, offset j_throw_complex_domainerror_729
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_188:                              # %oob421
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_226
.LBB0_190:                              # %oob421
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_190
.LBB0_226:                              # %oob421
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_228:                              # %oob431
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_231
.LBB0_230:                              # %oob431
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_230
.LBB0_231:                              # %oob431
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_87:                               # %oob147
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_213
.LBB0_89:                               # %oob147
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_89
.LBB0_213:                              # %oob147
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_215:                              # %oob157
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_218
.LBB0_217:                              # %oob157
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_217
.LBB0_218:                              # %oob157
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	"julia__sweep!_722", .Lfunc_end0-"julia__sweep!_722"
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
