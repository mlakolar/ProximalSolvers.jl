	.text
	.file	"_sweep!"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia__sweep!_1217
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
	.globl	"julia__sweep!_1217"
	.p2align	4, 0x90
	.type	"julia__sweep!_1217",@function
"julia__sweep!_1217":                   # @"julia__sweep!_1217"
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
	mov	r14, r9
	mov	qword ptr [rbx], rsi            # 8-byte Spill
	mov	dword ptr [rbx + 132], r8d      # 4-byte Spill
	mov	qword ptr [rbx + 168], rdx      # 8-byte Spill
	mov	qword ptr [rbx + 56], rdi       # 8-byte Spill
	vmovapd	ymmword ptr [rbx + 64], ymm0
	mov	qword ptr [rbx + 96], 0
	lea	rsi, [rbx + 64]
	mov	rdx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 64], 12
	mov	rax, qword ptr [rdx]
	mov	qword ptr [rbx + 216], rdx      # 8-byte Spill
	mov	qword ptr [rbx + 72], rax
	mov	qword ptr [rdx], rsi
	mov	r15, qword ptr [r9 + 16]
	sub	r15, qword ptr [r9 + 8]
	lea	rax, [r15 + 1]
	mov	rdx, rax
	sar	rdx, 63
	andn	rsi, rdx, rax
	test	byte ptr [rcx], 1
	mov	qword ptr [rbx + 136], rsi      # 8-byte Spill
	jne	.LBB0_1
# %bb.102:                              # %L551
	movabs	rax, 9223372036854775792
	vxorpd	xmm0, xmm0, xmm0
	add	rax, 14
	cmp	r15, rax
	ja	.LBB0_203
# %bb.103:                              # %L567.preheader
	movabs	rcx, offset .LCPI0_0
	mov	rax, qword ptr [r14]
	mov	rdx, qword ptr [r14 + 24]
	vxorpd	xmm14, xmm14, xmm14
	mov	r15d, 1
	vbroadcastsd	ymm0, qword ptr [rcx]
	mov	qword ptr [rbx + 120], rax      # 8-byte Spill
	movabs	rax, offset .LCPI0_1
	mov	qword ptr [rbx + 152], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vmovapd	ymm0, ymmword ptr [rax]
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovapd	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_104:                              # %L567
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_114 Depth 2
                                        #     Child Loop BB0_117 Depth 2
                                        #     Child Loop BB0_123 Depth 2
                                        #     Child Loop BB0_126 Depth 2
                                        #     Child Loop BB0_133 Depth 2
                                        #     Child Loop BB0_153 Depth 2
                                        #     Child Loop BB0_156 Depth 2
                                        #     Child Loop BB0_191 Depth 2
                                        #     Child Loop BB0_194 Depth 2
	mov	rcx, qword ptr [rbx + 120]      # 8-byte Reload
	mov	rax, qword ptr [rbx + 152]      # 8-byte Reload
	mov	rcx, qword ptr [rcx]
	add	rax, r15
	mov	r14, qword ptr [rcx + 8*rax - 8]
	mov	rcx, qword ptr [rbx]            # 8-byte Reload
	mov	r13, qword ptr [rcx]
	lea	r12, [r14 - 1]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_105
# %bb.108:                              # %idxend301
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovsd	qword ptr [rbx + 160], xmm0     # 8-byte Spill
	vmovsd	xmm15, qword ptr [rax + 8*r14 - 8] # xmm15 = mem[0],zero
	mov	rax, qword ptr [r13]
	mov	r11, qword ptr [rdi + 8]
	vucomisd	xmm15, xmm15
	jp	.LBB0_109
# %bb.118:                              # %L646
                                        #   in Loop: Header=BB0_104 Depth=1
	test	r11, r11
	je	.LBB0_119
# %bb.120:                              # %L659.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_122
# %bb.121:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm2, xmm2, xmm2
	xor	edx, edx
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_125
	.p2align	4, 0x90
.LBB0_119:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm2, xmm2, xmm2
	jmp	.LBB0_127
	.p2align	4, 0x90
.LBB0_122:                              # %vector.ph1631
                                        #   in Loop: Header=BB0_104 Depth=1
	vmovapd	ymm2, ymmword ptr [rbx + 256]   # 32-byte Reload
	vmovapd	ymm3, ymmword ptr [rbx + 288]   # 32-byte Reload
	movabs	rax, 9223372036854775792
	lea	rsi, [r8 + 8*r9 + 32]
	lea	rdx, [rax + 8]
	xor	eax, eax
	and	rdx, r11
	vmovapd	ymm0, ymm2
	vmovapd	ymm1, ymm3
	.p2align	4, 0x90
.LBB0_123:                              # %vector.body1636
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm4, ymmword ptr [rcx + 8*rax]
	vmovupd	ymm5, ymmword ptr [rcx + 8*rax + 32]
	vfmadd231pd	ymm0, ymm4, ymmword ptr [rsi + 8*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rsi + 8*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 8
	vfmadd231pd	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_123
# %bb.124:                              # %middle.block1628
                                        #   in Loop: Header=BB0_104 Depth=1
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
	vaddsd	xmm2, xmm0, xmm3
	je	.LBB0_127
.LBB0_125:                              # %scalar.ph1629
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rax, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_126:                              # %L659
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm2, xmm0, qword ptr [rax + 8*rdx] # xmm2 = (xmm0 * mem) + xmm2
	add	rdx, 1
	vfmadd231sd	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r11, rdx
	jne	.LBB0_126
.LBB0_127:                              # %L687
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm3, xmm6, xmm6
	vucomisd	xmm3, xmm3
	jp	.LBB0_128
.LBB0_129:                              # %L694
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm15, xmm14
	mov	rsi, qword ptr [rbx + 56]       # 8-byte Reload
	jne	.LBB0_135
	jp	.LBB0_135
# %bb.130:                              # %L696
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_135
# %bb.131:                              # %L709.preheader
                                        #   in Loop: Header=BB0_104 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_218
# %bb.132:                              # %ib347.us.preheader
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 8*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_133:                              # %ib347.us
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm14
	jne	.LBB0_239
	jp	.LBB0_239
# %bb.134:                              # %L715.us
                                        #   in Loop: Header=BB0_133 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_133
.LBB0_135:                              # %L735
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm0, xmm15, xmm15
	vucomisd	xmm0, xmm0
	jp	.LBB0_246
# %bb.136:                              # %L740
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rsi + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_240
# %bb.137:                              # %L754
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_138
# %bb.139:                              # %L759
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [rsi]
	mov	rcx, qword ptr [rcx]
	vmovsd	xmm0, qword ptr [rcx + 8*rax - 8] # xmm0 = mem[0],zero
	jmp	.LBB0_140
	.p2align	4, 0x90
.LBB0_138:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm0, xmm0, xmm0
.LBB0_140:                              # %L764
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm15, xmm14
	vmovsd	qword ptr [rbx + 32], xmm0      # 8-byte Spill
	jne	.LBB0_142
	jnp	.LBB0_141
.LBB0_142:                              # %L768
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rbx]            # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm10, xmm10, xmm10
	vcvtsi2sd	xmm1, xmm10, rax
	vmulsd	xmm1, xmm1, qword ptr [rsi]
	vucomisd	xmm15, xmm1
	jb	.LBB0_170
# %bb.143:                              # %L768
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm3, xmm3
	jp	.LBB0_170
# %bb.144:                              # %L768
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm6, xmm1
	jb	.LBB0_170
# %bb.145:                              # %L787
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm14, xmm15
	ja	.LBB0_241
# %bb.146:                              # %L793
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtsd	xmm5, xmm15, xmm15
	mov	rsi, qword ptr [rbx]            # 8-byte Reload
	vxorpd	xmm0, xmm0, xmm0
	vmovsd	xmm4, qword ptr [rsi + 8]       # xmm4 = mem[0],zero
	vucomisd	xmm4, xmm5
	jae	.LBB0_171
# %bb.147:                              # %L798
                                        #   in Loop: Header=BB0_104 Depth=1
	vdivsd	xmm3, xmm2, xmm15
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm0, xmm2, xmm3
	vmulsd	xmm2, xmm6, qword ptr [rsi]
	vsubsd	xmm0, xmm6, xmm0
	vucomisd	xmm2, xmm0
	jbe	.LBB0_160
# %bb.148:                              # %L805
                                        #   in Loop: Header=BB0_104 Depth=1
	test	rax, rax
	je	.LBB0_149
# %bb.150:                              # %L819.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_152
# %bb.151:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_155
	.p2align	4, 0x90
.LBB0_141:                              # %L766
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx + 168]      # 8-byte Reload
	mov	rsi, r14
	movabs	rax, offset j__coordinate_minimizer_1221
	mov	qword ptr [rbx + 88], r13
	vmovsd	qword ptr [rbx + 16], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_171
	.p2align	4, 0x90
.LBB0_170:                              # %L963
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 88], r13
	vmovsd	qword ptr [rbx + 16], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
.LBB0_171:                              # %L966
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_172
# %bb.175:                              # %idxend384
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm1, xmm0, qword ptr [rbx + 32] # 8-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovsd	qword ptr [rax + 8*r14 - 8], xmm15
	vucomisd	xmm1, xmm14
	jne	.LBB0_176
	jnp	.LBB0_196
.LBB0_176:                              # %L974
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdx, qword ptr [rbx + 56]       # 8-byte Reload
	mov	rdi, qword ptr [rdx + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_245
# %bb.177:                              # %L988
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_182
# %bb.178:                              # %L993
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [rdx]
	mov	rcx, qword ptr [rcx]
	vmovsd	qword ptr [rcx + 8*rax - 8], xmm0
	jmp	.LBB0_179
	.p2align	4, 0x90
.LBB0_182:                              # %L996
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm0, xmm14
	jne	.LBB0_183
	jnp	.LBB0_179
.LBB0_183:                              # %L999
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rdx + 24]
	lea	r8, [rax + 1]
	mov	qword ptr [rdx + 24], r8
	mov	rdi, qword ptr [rdx]
	cmp	rax, qword ptr [rdi + 8]
	jae	.LBB0_184
# %bb.224:                              # %idxend440
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovsd	qword ptr [rsi + 8*rax], xmm0
	mov	rdi, qword ptr [rdx + 8]
	cmp	rax, qword ptr [rdi + 8]
	jae	.LBB0_225
# %bb.229:                              # %idxend460
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rax], r14
	mov	qword ptr [rcx + 8*r14 - 8], r8
	.p2align	4, 0x90
.LBB0_179:                              # %L1013
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 8], r14        # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_196
# %bb.180:                              # %L1026.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 16
	jae	.LBB0_187
# %bb.181:                              #   in Loop: Header=BB0_104 Depth=1
	xor	esi, esi
	jmp	.LBB0_193
.LBB0_187:                              # %vector.memcheck1555
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 8*rdx]
	cmp	rcx, rdx
	jae	.LBB0_190
# %bb.188:                              # %vector.memcheck1555
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [rcx + 8*rax]
	lea	rsi, [r8 + 8*r12]
	cmp	rsi, rdx
	jae	.LBB0_190
# %bb.189:                              #   in Loop: Header=BB0_104 Depth=1
	xor	esi, esi
	jmp	.LBB0_193
.LBB0_190:                              # %vector.ph1569
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastsd	ymm0, xmm1
	lea	rdi, [r8 + 8*r12 + 96]
	and	rsi, rdx
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_191:                              # %vector.body1574
                                        #   Parent Loop BB0_104 Depth=1
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
	jne	.LBB0_191
# %bb.192:                              # %middle.block1566
                                        #   in Loop: Header=BB0_104 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 8], r14        # 8-byte Spill
	je	.LBB0_196
	.p2align	4, 0x90
.LBB0_193:                              # %scalar.ph1567
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [r8 + 8*r12]
	.p2align	4, 0x90
.LBB0_194:                              # %L1026
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm0, xmm1, qword ptr [rdx + 8*rsi]
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm0, xmm2, xmm0
	vmovsd	qword ptr [rcx + 8*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_194
# %bb.195:                              #   in Loop: Header=BB0_104 Depth=1
	mov	qword ptr [rbx + 8], r14        # 8-byte Spill
.LBB0_196:                              # %L1050
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rax, offset .LCPI0_7
	test	byte ptr [rbx + 132], 1         # 1-byte Folded Reload
	vandpd	xmm2, xmm1, xmmword ptr [rax]
	je	.LBB0_197
# %bb.198:                              # %L1050
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm1, xmm14
	mov	r12, qword ptr [rbx + 136]      # 8-byte Reload
	jne	.LBB0_199
	jnp	.LBB0_200
.LBB0_199:                              # %L1056
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rbx]            # 8-byte Reload
	mov	rsi, qword ptr [rbx + 56]       # 8-byte Reload
	mov	rdx, r14
	vmovapd	xmmword ptr [rbx + 32], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1222
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
	vmovapd	xmm2, xmmword ptr [rbx + 32]    # 16-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	vmulsd	xmm2, xmm2, xmm0
	jmp	.LBB0_200
	.p2align	4, 0x90
.LBB0_197:                              #   in Loop: Header=BB0_104 Depth=1
	mov	r12, qword ptr [rbx + 136]      # 8-byte Reload
.LBB0_200:                              # %L1061
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm0, xmm2, xmm2
	vucomisd	xmm0, xmm0
	jp	.LBB0_247
# %bb.201:                              # %L1070
                                        #   in Loop: Header=BB0_104 Depth=1
	vmovsd	xmm0, qword ptr [rbx + 160]     # 8-byte Reload
                                        # xmm0 = mem[0],zero
	cmp	r15, r12
	lea	r15, [r15 + 1]
	vmaxsd	xmm0, xmm2, xmm0
	jne	.LBB0_104
	jmp	.LBB0_202
.LBB0_149:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_157
.LBB0_152:                              # %vector.ph1596
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rdx, offset .LCPI0_0
	movabs	rsi, 9223372036854775792
	vbroadcastsd	ymm6, xmm3
	lea	rdi, [r8 + 8*r9 + 96]
	vbroadcastsd	ymm0, qword ptr [rdx]
	mov	rdx, rax
	and	rdx, rsi
	movabs	rsi, offset .LCPI0_1
	vmovapd	ymm2, ymmword ptr [rsi]
	xor	esi, esi
	vmovapd	ymm7, ymm0
	vmovapd	ymm8, ymm0
	.p2align	4, 0x90
.LBB0_153:                              # %vector.body1601
                                        #   Parent Loop BB0_104 Depth=1
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
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vsubpd	ymm11, ymm13, ymm11
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi + 96]
	add	rsi, 16
	vfmadd231pd	ymm0, ymm10, ymm10      # ymm0 = (ymm10 * ymm10) + ymm0
	cmp	rdx, rsi
	vsubpd	ymm12, ymm13, ymm12
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	jne	.LBB0_153
# %bb.154:                              # %middle.block1593
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddpd	ymm0, ymm0, ymm2
	cmp	rax, rdx
	vaddpd	ymm0, ymm7, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm2
	je	.LBB0_157
.LBB0_155:                              # %scalar.ph1594
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rsi, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_156:                              # %L819
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm2, xmm3, qword ptr [rsi + 8*rdx]
	vmovsd	xmm6, qword ptr [rcx + 8*rdx]   # xmm6 = mem[0],zero
	add	rdx, 1
	cmp	rax, rdx
	vsubsd	xmm2, xmm6, xmm2
	vfmadd231sd	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_156
.LBB0_157:                              # %L842
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm0, xmm1
	jb	.LBB0_159
# %bb.158:                              # %L842
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm1, xmm0, xmm0
	vucomisd	xmm1, xmm1
	jp	.LBB0_159
.LBB0_160:                              # %L853
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm14, xmm0
	ja	.LBB0_242
# %bb.161:                              # %L858
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubsd	xmm1, xmm5, xmm4
	vucomisd	xmm14, xmm1
	ja	.LBB0_243
# %bb.162:                              # %L865
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddsd	xmm2, xmm5, xmm4
	vucomisd	xmm14, xmm2
	ja	.LBB0_244
# %bb.163:                              # %L872
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtsd	xmm1, xmm1, xmm1
	vsqrtsd	xmm2, xmm2, xmm2
	movabs	rax, offset .LCPI0_4
	vmulsd	xmm1, xmm1, xmm2
	vmulsd	xmm1, xmm5, xmm1
	vucomisd	xmm1, qword ptr [rax]
	jb	.LBB0_169
# %bb.164:                              # %L872
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtsd	xmm0, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vdivsd	xmm0, xmm0, xmm1
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_169
# %bb.165:                              # %L872
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovsd	xmm1, qword ptr [rax]           # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm0
	jb	.LBB0_169
# %bb.166:                              # %L872
                                        #   in Loop: Header=BB0_104 Depth=1
	vmulsd	xmm0, xmm4, xmm0
	movabs	rax, offset .LCPI0_4
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_169
# %bb.167:                              # %L872
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomisd	xmm1, xmm0
	jb	.LBB0_169
# %bb.168:                              # %L906
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddsd	xmm1, xmm3, qword ptr [rbx + 32] # 8-byte Folded Reload
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm2, xmm0, xmmword ptr [rax]
	vmaxsd	xmm2, xmm1, xmm2
	vminsd	xmm0, xmm2, xmm0
	vsubsd	xmm0, xmm1, xmm0
	vaddsd	xmm0, xmm14, xmm0
	jmp	.LBB0_171
.LBB0_169:                              # %L961
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 32]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 88], r13
	vmovsd	qword ptr [rbx + 16], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_171
.LBB0_159:                              # %L851
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 32]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 88], r13
	vmovsd	qword ptr [rbx + 16], xmm15     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_171
.LBB0_109:                              # %L603
                                        #   in Loop: Header=BB0_104 Depth=1
	test	r11, r11
	je	.LBB0_110
# %bb.111:                              # %L617.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	r10, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_113
# %bb.112:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm15, xmm15, xmm15
	xor	edx, edx
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_116
.LBB0_128:                              # %L692
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, r14
	movabs	rax, offset j__check_residual_1228
	mov	qword ptr [rbx + 88], r13
	mov	qword ptr [rbx + 80], rdi
	vmovsd	qword ptr [rbx + 16], xmm15     # 8-byte Spill
	vmovsd	qword ptr [rbx + 32], xmm6      # 8-byte Spill
	vmovsd	qword ptr [rbx + 224], xmm2     # 8-byte Spill
	vmovsd	qword ptr [rbx + 144], xmm3     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm3, qword ptr [rbx + 144]     # 8-byte Reload
                                        # xmm3 = mem[0],zero
	vmovsd	xmm2, qword ptr [rbx + 224]     # 8-byte Reload
                                        # xmm2 = mem[0],zero
	vmovsd	xmm6, qword ptr [rbx + 32]      # 8-byte Reload
                                        # xmm6 = mem[0],zero
	vmovsd	xmm15, qword ptr [rbx + 16]     # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_129
.LBB0_110:                              #   in Loop: Header=BB0_104 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm15, xmm15, xmm15
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_127
.LBB0_113:                              # %vector.ph1654
                                        #   in Loop: Header=BB0_104 Depth=1
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
.LBB0_114:                              # %vector.body1659
                                        #   Parent Loop BB0_104 Depth=1
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
	jne	.LBB0_114
# %bb.115:                              # %middle.block1651
                                        #   in Loop: Header=BB0_104 Depth=1
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
	vaddsd	xmm2, xmm2, xmm1
	vaddsd	xmm15, xmm0, xmm3
	je	.LBB0_127
.LBB0_116:                              # %scalar.ph1652
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rax, [r8 + 8*r9]
.LBB0_117:                              # %L617
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rax + 8*rdx]   # xmm0 = mem[0],zero
	vmovsd	xmm1, qword ptr [r10 + 8*rdx]   # xmm1 = mem[0],zero
	add	rdx, 1
	cmp	r11, rdx
	vfmadd231sd	xmm15, xmm0, xmm0       # xmm15 = (xmm0 * xmm0) + xmm15
	vfmadd231sd	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231sd	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_117
	jmp	.LBB0_127
.LBB0_1:                                # %L12
	mov	rdi, qword ptr [rcx + 8]
	movabs	rax, offset "j__shuffle!_1219"
	movabs	r12, 9223372036854775792
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
	lea	rcx, [r12 + 14]
	vxorpd	xmm0, xmm0, xmm0
	mov	qword ptr [rbx + 32], rax       # 8-byte Spill
	cmp	r15, rcx
	ja	.LBB0_203
# %bb.2:                                # %L30.preheader
	movabs	rcx, offset .LCPI0_0
	mov	rax, qword ptr [r14]
	mov	rdx, qword ptr [r14 + 24]
	vxorpd	xmm14, xmm14, xmm14
	mov	r15d, 1
	vbroadcastsd	ymm0, qword ptr [rcx]
	mov	qword ptr [rbx + 152], rax      # 8-byte Spill
	movabs	rax, offset .LCPI0_1
	mov	qword ptr [rbx + 288], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovapd	ymm0, ymmword ptr [rax]
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovapd	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_3:                                # %L30
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_13 Depth 2
                                        #     Child Loop BB0_16 Depth 2
                                        #     Child Loop BB0_22 Depth 2
                                        #     Child Loop BB0_25 Depth 2
                                        #     Child Loop BB0_32 Depth 2
                                        #     Child Loop BB0_52 Depth 2
                                        #     Child Loop BB0_55 Depth 2
                                        #     Child Loop BB0_90 Depth 2
                                        #     Child Loop BB0_93 Depth 2
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 152]      # 8-byte Reload
	mov	rax, qword ptr [rax]
	mov	rcx, qword ptr [rcx]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	add	rax, qword ptr [rbx + 288]      # 8-byte Folded Reload
	mov	r14, qword ptr [rcx + 8*rax - 8]
	mov	rcx, qword ptr [rbx]            # 8-byte Reload
	mov	r13, qword ptr [rcx]
	lea	r12, [r14 - 1]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_4
# %bb.7:                                # %idxend
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovsd	qword ptr [rbx + 160], xmm0     # 8-byte Spill
	vmovsd	xmm15, qword ptr [rax + 8*r14 - 8] # xmm15 = mem[0],zero
	mov	rax, qword ptr [r13]
	mov	r11, qword ptr [rdi + 8]
	vucomisd	xmm15, xmm15
	jp	.LBB0_8
# %bb.17:                               # %L110
                                        #   in Loop: Header=BB0_3 Depth=1
	test	r11, r11
	je	.LBB0_18
# %bb.19:                               # %L123.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_21
# %bb.20:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm2, xmm2, xmm2
	xor	edx, edx
	vxorpd	xmm6, xmm6, xmm6
	jmp	.LBB0_24
	.p2align	4, 0x90
.LBB0_18:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm2, xmm2, xmm2
	jmp	.LBB0_26
	.p2align	4, 0x90
.LBB0_21:                               # %vector.ph1508
                                        #   in Loop: Header=BB0_3 Depth=1
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
.LBB0_22:                               # %vector.body1513
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm4, ymmword ptr [rcx + 8*rax]
	vmovupd	ymm5, ymmword ptr [rcx + 8*rax + 32]
	vfmadd231pd	ymm0, ymm4, ymmword ptr [rsi + 8*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231pd	ymm1, ymm5, ymmword ptr [rsi + 8*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 8
	vfmadd231pd	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_22
# %bb.23:                               # %middle.block1505
                                        #   in Loop: Header=BB0_3 Depth=1
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
	vaddsd	xmm2, xmm0, xmm3
	je	.LBB0_26
.LBB0_24:                               # %scalar.ph1506
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rax, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_25:                               # %L123
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm2, xmm0, qword ptr [rax + 8*rdx] # xmm2 = (xmm0 * mem) + xmm2
	add	rdx, 1
	vfmadd231sd	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r11, rdx
	jne	.LBB0_25
.LBB0_26:                               # %L151
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm3, xmm6, xmm6
	vucomisd	xmm3, xmm3
	jp	.LBB0_27
.LBB0_28:                               # %L158
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm15, xmm14
	mov	rsi, qword ptr [rbx + 56]       # 8-byte Reload
	jne	.LBB0_34
	jp	.LBB0_34
# %bb.29:                               # %L160
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_34
# %bb.30:                               # %L173.preheader
                                        #   in Loop: Header=BB0_3 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_205
# %bb.31:                               # %ib.us.preheader
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 8*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_32:                               # %ib.us
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rcx + 8*rdx]   # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm14
	jne	.LBB0_230
	jp	.LBB0_230
# %bb.33:                               # %L179.us
                                        #   in Loop: Header=BB0_32 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_32
.LBB0_34:                               # %L199
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm0, xmm15, xmm15
	vucomisd	xmm0, xmm0
	jp	.LBB0_237
# %bb.35:                               # %L204
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [rsi + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_231
# %bb.36:                               # %L218
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_37
# %bb.38:                               # %L223
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [rsi]
	mov	rcx, qword ptr [rcx]
	vmovsd	xmm0, qword ptr [rcx + 8*rax - 8] # xmm0 = mem[0],zero
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_37:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm0, xmm0, xmm0
.LBB0_39:                               # %L228
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm15, xmm14
	vmovsd	qword ptr [rbx + 16], xmm0      # 8-byte Spill
	jne	.LBB0_41
	jnp	.LBB0_40
.LBB0_41:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx]            # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vxorps	xmm10, xmm10, xmm10
	vcvtsi2sd	xmm1, xmm10, rax
	vmulsd	xmm1, xmm1, qword ptr [rsi]
	vucomisd	xmm15, xmm1
	jb	.LBB0_69
# %bb.42:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm3, xmm3
	jp	.LBB0_69
# %bb.43:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm6, xmm1
	jb	.LBB0_69
# %bb.44:                               # %L251
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm14, xmm15
	ja	.LBB0_232
# %bb.45:                               # %L257
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtsd	xmm5, xmm15, xmm15
	mov	rsi, qword ptr [rbx]            # 8-byte Reload
	vxorpd	xmm0, xmm0, xmm0
	vmovsd	xmm4, qword ptr [rsi + 8]       # xmm4 = mem[0],zero
	vucomisd	xmm4, xmm5
	jae	.LBB0_70
# %bb.46:                               # %L262
                                        #   in Loop: Header=BB0_3 Depth=1
	vdivsd	xmm3, xmm2, xmm15
	movabs	rsi, offset .LCPI0_3
	vmulsd	xmm0, xmm2, xmm3
	vmulsd	xmm2, xmm6, qword ptr [rsi]
	vsubsd	xmm0, xmm6, xmm0
	vucomisd	xmm2, xmm0
	jbe	.LBB0_59
# %bb.47:                               # %L269
                                        #   in Loop: Header=BB0_3 Depth=1
	test	rax, rax
	je	.LBB0_48
# %bb.49:                               # %L283.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_51
# %bb.50:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_54
	.p2align	4, 0x90
.LBB0_40:                               # %L230
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 168]      # 8-byte Reload
	mov	rsi, r14
	vmovsd	qword ptr [rbx + 8], xmm15      # 8-byte Spill
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset j__coordinate_minimizer_1221
	mov	qword ptr [rbx + 96], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 8]      # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_70
	.p2align	4, 0x90
.LBB0_69:                               # %L427
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	mov	rsi, r14
	vmovsd	qword ptr [rbx + 8], xmm15      # 8-byte Spill
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 96], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 8]      # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
.LBB0_70:                               # %L430
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_71
# %bb.74:                               # %idxend101
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm1, xmm0, qword ptr [rbx + 16] # 8-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovsd	qword ptr [rax + 8*r14 - 8], xmm15
	vucomisd	xmm1, xmm14
	jne	.LBB0_75
	jnp	.LBB0_95
.LBB0_75:                               # %L438
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdx, qword ptr [rbx + 56]       # 8-byte Reload
	mov	rdi, qword ptr [rdx + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_236
# %bb.76:                               # %L452
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_81
# %bb.77:                               # %L457
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [rdx]
	mov	rcx, qword ptr [rcx]
	vmovsd	qword ptr [rcx + 8*rax - 8], xmm0
	jmp	.LBB0_78
	.p2align	4, 0x90
.LBB0_81:                               # %L460
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm0, xmm14
	jne	.LBB0_82
	jnp	.LBB0_78
.LBB0_82:                               # %L463
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rdx + 24]
	lea	r8, [rax + 1]
	mov	qword ptr [rdx + 24], r8
	mov	rdi, qword ptr [rdx]
	cmp	rax, qword ptr [rdi + 8]
	jae	.LBB0_83
# %bb.211:                              # %idxend159
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovsd	qword ptr [rsi + 8*rax], xmm0
	mov	rdi, qword ptr [rdx + 8]
	cmp	rax, qword ptr [rdi + 8]
	jae	.LBB0_212
# %bb.216:                              # %idxend179
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rax], r14
	mov	qword ptr [rcx + 8*r14 - 8], r8
	.p2align	4, 0x90
.LBB0_78:                               # %L477
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 120], r14      # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_95
# %bb.79:                               # %L490.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 16
	jae	.LBB0_86
# %bb.80:                               #   in Loop: Header=BB0_3 Depth=1
	xor	esi, esi
	jmp	.LBB0_92
.LBB0_86:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 8*rdx]
	cmp	rcx, rdx
	jae	.LBB0_89
# %bb.87:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [rcx + 8*rax]
	lea	rsi, [r8 + 8*r12]
	cmp	rsi, rdx
	jae	.LBB0_89
# %bb.88:                               #   in Loop: Header=BB0_3 Depth=1
	xor	esi, esi
	jmp	.LBB0_92
.LBB0_89:                               # %vector.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastsd	ymm0, xmm1
	lea	rdi, [r8 + 8*r12 + 96]
	and	rsi, rdx
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_90:                               # %vector.body
                                        #   Parent Loop BB0_3 Depth=1
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
	jne	.LBB0_90
# %bb.91:                               # %middle.block
                                        #   in Loop: Header=BB0_3 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 120], r14      # 8-byte Spill
	je	.LBB0_95
	.p2align	4, 0x90
.LBB0_92:                               # %scalar.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [r8 + 8*r12]
	.p2align	4, 0x90
.LBB0_93:                               # %L490
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm0, xmm1, qword ptr [rdx + 8*rsi]
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm0, xmm2, xmm0
	vmovsd	qword ptr [rcx + 8*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_93
# %bb.94:                               #   in Loop: Header=BB0_3 Depth=1
	mov	qword ptr [rbx + 120], r14      # 8-byte Spill
.LBB0_95:                               # %L514
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rax, offset .LCPI0_7
	test	byte ptr [rbx + 132], 1         # 1-byte Folded Reload
	vandpd	xmm2, xmm1, xmmword ptr [rax]
	je	.LBB0_96
# %bb.97:                               # %L514
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm1, xmm14
	mov	r12, qword ptr [rbx + 136]      # 8-byte Reload
	jne	.LBB0_98
	jnp	.LBB0_99
.LBB0_98:                               # %L520
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx]            # 8-byte Reload
	mov	rcx, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, qword ptr [rbx + 56]       # 8-byte Reload
	mov	rdx, r14
	vmovapd	xmmword ptr [rbx + 16], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1222
	mov	qword ptr [rbx + 88], rcx
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
	vmovapd	xmm2, xmmword ptr [rbx + 16]    # 16-byte Reload
	vxorpd	xmm14, xmm14, xmm14
	vmulsd	xmm2, xmm2, xmm0
	jmp	.LBB0_99
	.p2align	4, 0x90
.LBB0_96:                               #   in Loop: Header=BB0_3 Depth=1
	mov	r12, qword ptr [rbx + 136]      # 8-byte Reload
.LBB0_99:                               # %L525
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm0, xmm2, xmm2
	vucomisd	xmm0, xmm0
	jp	.LBB0_238
# %bb.100:                              # %L534
                                        #   in Loop: Header=BB0_3 Depth=1
	vmovsd	xmm0, qword ptr [rbx + 160]     # 8-byte Reload
                                        # xmm0 = mem[0],zero
	cmp	r15, r12
	lea	r15, [r15 + 1]
	vmaxsd	xmm0, xmm2, xmm0
	jne	.LBB0_3
	jmp	.LBB0_101
.LBB0_48:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_56
.LBB0_51:                               # %vector.ph1476
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rdx, offset .LCPI0_0
	movabs	rsi, 9223372036854775792
	vbroadcastsd	ymm6, xmm3
	lea	rdi, [r8 + 8*r9 + 96]
	vbroadcastsd	ymm0, qword ptr [rdx]
	mov	rdx, rax
	and	rdx, rsi
	movabs	rsi, offset .LCPI0_1
	vmovapd	ymm2, ymmword ptr [rsi]
	xor	esi, esi
	vmovapd	ymm7, ymm0
	vmovapd	ymm8, ymm0
	.p2align	4, 0x90
.LBB0_52:                               # %vector.body1481
                                        #   Parent Loop BB0_3 Depth=1
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
	vfmadd231pd	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vsubpd	ymm11, ymm13, ymm11
	vmovupd	ymm13, ymmword ptr [rcx + 8*rsi + 96]
	add	rsi, 16
	vfmadd231pd	ymm0, ymm10, ymm10      # ymm0 = (ymm10 * ymm10) + ymm0
	cmp	rdx, rsi
	vsubpd	ymm12, ymm13, ymm12
	vfmadd231pd	ymm7, ymm11, ymm11      # ymm7 = (ymm11 * ymm11) + ymm7
	vfmadd231pd	ymm8, ymm12, ymm12      # ymm8 = (ymm12 * ymm12) + ymm8
	jne	.LBB0_52
# %bb.53:                               # %middle.block1473
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddpd	ymm0, ymm0, ymm2
	cmp	rax, rdx
	vaddpd	ymm0, ymm7, ymm0
	vaddpd	ymm0, ymm8, ymm0
	vextractf128	xmm2, ymm0, 1
	vaddpd	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddsd	xmm0, xmm0, xmm2
	je	.LBB0_56
.LBB0_54:                               # %scalar.ph1474
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rsi, [r8 + 8*r9]
	.p2align	4, 0x90
.LBB0_55:                               # %L283
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulsd	xmm2, xmm3, qword ptr [rsi + 8*rdx]
	vmovsd	xmm6, qword ptr [rcx + 8*rdx]   # xmm6 = mem[0],zero
	add	rdx, 1
	cmp	rax, rdx
	vsubsd	xmm2, xmm6, xmm2
	vfmadd231sd	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_55
.LBB0_56:                               # %L306
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm0, xmm1
	jb	.LBB0_58
# %bb.57:                               # %L306
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm1, xmm0, xmm0
	vucomisd	xmm1, xmm1
	jp	.LBB0_58
.LBB0_59:                               # %L317
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm14, xmm0
	ja	.LBB0_233
# %bb.60:                               # %L322
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubsd	xmm1, xmm5, xmm4
	vucomisd	xmm14, xmm1
	ja	.LBB0_234
# %bb.61:                               # %L329
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddsd	xmm2, xmm5, xmm4
	vucomisd	xmm14, xmm2
	ja	.LBB0_235
# %bb.62:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtsd	xmm1, xmm1, xmm1
	vsqrtsd	xmm2, xmm2, xmm2
	movabs	rax, offset .LCPI0_4
	vmulsd	xmm1, xmm1, xmm2
	vmulsd	xmm1, xmm5, xmm1
	vucomisd	xmm1, qword ptr [rax]
	jb	.LBB0_68
# %bb.63:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtsd	xmm0, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vdivsd	xmm0, xmm0, xmm1
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_68
# %bb.64:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovsd	xmm1, qword ptr [rax]           # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm0
	jb	.LBB0_68
# %bb.65:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vmulsd	xmm0, xmm4, xmm0
	movabs	rax, offset .LCPI0_4
	vucomisd	xmm0, qword ptr [rax]
	jb	.LBB0_68
# %bb.66:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomisd	xmm1, xmm0
	jb	.LBB0_68
# %bb.67:                               # %L370
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddsd	xmm1, xmm3, qword ptr [rbx + 16] # 8-byte Folded Reload
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm2, xmm0, xmmword ptr [rax]
	vmaxsd	xmm2, xmm1, xmm2
	vminsd	xmm0, xmm2, xmm0
	vsubsd	xmm0, xmm1, xmm0
	vaddsd	xmm0, xmm14, xmm0
	jmp	.LBB0_70
.LBB0_68:                               # %L425
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 16]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r14
	vmovsd	qword ptr [rbx + 8], xmm15      # 8-byte Spill
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 96], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 8]      # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_70
.LBB0_58:                               # %L315
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rdi, qword ptr [rbx]            # 8-byte Reload
	vmovsd	xmm0, qword ptr [rbx + 16]      # 8-byte Reload
                                        # xmm0 = mem[0],zero
	mov	rsi, r14
	vmovsd	qword ptr [rbx + 8], xmm15      # 8-byte Spill
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset j__sqrt_offrange_step_1226
	mov	qword ptr [rbx + 96], r13
	vzeroupper
	call	rax
	vmovsd	xmm15, qword ptr [rbx + 8]      # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_70
.LBB0_8:                                # %L67
                                        #   in Loop: Header=BB0_3 Depth=1
	test	r11, r11
	je	.LBB0_9
# %bb.10:                               # %L81.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	r10, qword ptr [rdi]
	imul	r9, r12
	cmp	r11, 8
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm15, xmm15, xmm15
	xor	edx, edx
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_15
.LBB0_27:                               # %L156
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r14
	vmovsd	qword ptr [rbx + 8], xmm15      # 8-byte Spill
	vmovsd	qword ptr [rbx + 16], xmm6      # 8-byte Spill
	vmovsd	qword ptr [rbx + 144], xmm2     # 8-byte Spill
	vmovsd	qword ptr [rbx + 208], xmm3     # 8-byte Spill
	mov	qword ptr [rbx + 88], rax
	movabs	rax, offset j__check_residual_1228
	mov	qword ptr [rbx + 96], r13
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
	vmovsd	xmm3, qword ptr [rbx + 208]     # 8-byte Reload
                                        # xmm3 = mem[0],zero
	vmovsd	xmm2, qword ptr [rbx + 144]     # 8-byte Reload
                                        # xmm2 = mem[0],zero
	vmovsd	xmm6, qword ptr [rbx + 16]      # 8-byte Reload
                                        # xmm6 = mem[0],zero
	vmovsd	xmm15, qword ptr [rbx + 8]      # 8-byte Reload
                                        # xmm15 = mem[0],zero
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_28
.LBB0_9:                                #   in Loop: Header=BB0_3 Depth=1
	vxorpd	xmm6, xmm6, xmm6
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm15, xmm15, xmm15
	vxorpd	xmm14, xmm14, xmm14
	jmp	.LBB0_26
.LBB0_12:                               # %vector.ph1531
                                        #   in Loop: Header=BB0_3 Depth=1
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
.LBB0_13:                               # %vector.body1536
                                        #   Parent Loop BB0_3 Depth=1
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
	jne	.LBB0_13
# %bb.14:                               # %middle.block1528
                                        #   in Loop: Header=BB0_3 Depth=1
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
	vaddsd	xmm2, xmm2, xmm1
	vaddsd	xmm15, xmm0, xmm3
	je	.LBB0_26
.LBB0_15:                               # %scalar.ph1529
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rax, [r8 + 8*r9]
.LBB0_16:                               # %L81
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rax + 8*rdx]   # xmm0 = mem[0],zero
	vmovsd	xmm1, qword ptr [r10 + 8*rdx]   # xmm1 = mem[0],zero
	add	rdx, 1
	cmp	r11, rdx
	vfmadd231sd	xmm15, xmm0, xmm0       # xmm15 = (xmm0 * xmm0) + xmm15
	vfmadd231sd	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231sd	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_16
	jmp	.LBB0_26
.LBB0_202:                              # %L1085.loopexit
	mov	rax, qword ptr [rbx + 8]        # 8-byte Reload
	mov	qword ptr [rbx + 184], r14
	mov	qword ptr [rbx + 176], rax
	jmp	.LBB0_203
.LBB0_101:                              # %L1085.loopexit699
	mov	rax, qword ptr [rbx + 120]      # 8-byte Reload
	mov	qword ptr [rbx + 200], r14
	mov	qword ptr [rbx + 192], rax
.LBB0_203:                              # %L1085
	mov	rax, qword ptr [rbx + 72]
	mov	rcx, qword ptr [rbx + 216]      # 8-byte Reload
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
.LBB0_239:                              # %L731.split.us
	movabs	rax, 135794558905424
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 48]
	mov	edx, 1
	mov	qword ptr [rbx + 48], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_230:                              # %L195.split.us
	movabs	rax, 135794558905424
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 48]
	mov	edx, 1
	mov	qword ptr [rbx + 48], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_105:                              # %oob299
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_217
.LBB0_107:                              # %oob299
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_107
.LBB0_217:                              # %oob299
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_246:                              # %L1048
	movabs	rax, offset j__refuse_curvature_1227
	mov	rdi, r14
	vzeroupper
	call	rax
.LBB0_240:                              # %L751
	movabs	rax, offset j_throw_boundserror_1223
	lea	rsi, [rbx + 184]
	mov	qword ptr [rbx + 184], r14
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
.LBB0_172:                              # %oob382
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_222
.LBB0_174:                              # %oob382
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_174
.LBB0_222:                              # %oob382
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_247:                              # %L1067
	movabs	rax, 135794567639056
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 48]
	mov	edx, 1
	mov	qword ptr [rbx + 48], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_4:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_204
.LBB0_6:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_6
.LBB0_204:                              # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_237:                              # %L512
	movabs	rax, offset j__refuse_curvature_1227
	mov	rdi, r14
	vzeroupper
	call	rax
.LBB0_231:                              # %L215
	movabs	rax, offset j_throw_boundserror_1223
	lea	rsi, [rbx + 200]
	mov	qword ptr [rbx + 200], r14
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
.LBB0_71:                               # %oob99
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_209
.LBB0_73:                               # %oob99
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_73
.LBB0_209:                              # %oob99
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_238:                              # %L531
	movabs	rax, 135794567639056
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 48]
	mov	edx, 1
	mov	qword ptr [rbx + 48], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_245:                              # %L985
	movabs	rax, offset j_throw_boundserror_1223
	lea	rsi, [rbx + 176]
	mov	qword ptr [rbx + 176], r14
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
.LBB0_236:                              # %L449
	movabs	rax, offset j_throw_boundserror_1223
	lea	rsi, [rbx + 192]
	mov	qword ptr [rbx + 192], r14
	mov	qword ptr [rbx + 80], rdi
	vzeroupper
	call	rax
.LBB0_241:                              # %L791
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm15
	vzeroupper
	call	rax
.LBB0_232:                              # %L255
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm15
	vzeroupper
	call	rax
.LBB0_218:                              # %oob352
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_221
.LBB0_220:                              # %oob352
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_220
.LBB0_221:                              # %oob352
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r14
	vzeroupper
	call	rax
.LBB0_205:                              # %oob70
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_208
.LBB0_207:                              # %oob70
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_207
.LBB0_208:                              # %oob70
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r14
	vzeroupper
	call	rax
.LBB0_242:                              # %L856
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_243:                              # %L863
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_244:                              # %L870
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_233:                              # %L320
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_234:                              # %L327
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_235:                              # %L334
	movabs	rax, offset j_throw_complex_domainerror_1224
	movabs	rdi, 135794596555280
	vmovapd	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_184:                              # %oob438
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_223
.LBB0_186:                              # %oob438
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_186
.LBB0_223:                              # %oob438
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r8
	vzeroupper
	call	rax
.LBB0_225:                              # %oob448
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_228
.LBB0_227:                              # %oob448
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_227
.LBB0_228:                              # %oob448
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r8
	vzeroupper
	call	rax
.LBB0_83:                               # %oob157
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_210
.LBB0_85:                               # %oob157
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_85
.LBB0_210:                              # %oob157
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r8
	vzeroupper
	call	rax
.LBB0_212:                              # %oob167
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_215
.LBB0_214:                              # %oob167
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_214
.LBB0_215:                              # %oob167
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r8
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	"julia__sweep!_1217", .Lfunc_end0-"julia__sweep!_1217"
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
