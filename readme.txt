makefile 的调试. remake
--------------------------------------------
author: hjjdebug
date:   2022年 12月 27日 星期二 17:54:57 CST
--------------------------------------------

1. 简单使用, 列出一些信息
----------------------------------------
remake --tasks		//列出Makefile 的目标,该目录会有命令执行来生成. --targets 是更详细的目标
remake --trace		//跟踪维护的目标, 每一个运行的命令将会显示
remake --profile	//列出构建过程中各部分消耗的时间

tutorial document
https://remake.readthedocs.io/en/latest/

----------------------------------------
2. 使用debugger
----------------------------------------
remake --debugger 进入debugger 调试状态
可以单步，断点，检查变量，调用堆栈，查看目标等.

下面的命令都是debugger 命令， 用h 可看到可用的命令列表，与gdb 很相似.
1. 显示Makefile 信息, info 命令
info 命令, 显示可用的info 命令
包括frame信息，break 信息, variable信息等
info program
info frame		; 这何bt 命令显示一致,显示调用栈 (backtrace 命令）
info break
info variable

2. 单步执行, step 命令
3. 在目标处设置断点， 再运行continue 命令， 会中断在断点处。再单步执行

4. debug Makefile变量
	用p 命令可以打印 Makefile 中变量.直接输入变量名称即可， 与gdb 很像. 
	如果用info variable 你会看到很多很多变量.

5. 显示当前的目标
  target 命令, 显示当前目标信息
  还可以进一步分为
  target @ variable 	; 显示自动变量部分

例如:
remake<3> target @ variables

boot:
# automatic
# @ := boot
# automatic
# % := 
# automatic
# * := 
# automatic
# + := boot.s
# automatic
# | := 
# automatic
# < := boot.s
# automatic
# ^ := boot.s
# automatic
# ? := 
# variable set hash-table stats:
# Load=8/32=25%, Rehash=0, Collisions=3/27=11%

  target @ commands 	; 显示执行命令部分

例如:
remake<4> target @ commands

boot:
#  recipe to execute (from 'Makefile', line 40):
	$(AS86) -o boot.o boot.s
	$(LD86) -s -o boot boot.o

  target @ expand 		; 显示展开后的命令，如果可展开的话.
  
例如:
remake<6> target @ expand

boot:
#  recipe to execute (from 'Makefile', line 40):
	as86 -0 -a -o boot.o boot.s
	ld86 -0 -s -o boot boot.o

  终于把Make 的过程也可以就近观察了！
