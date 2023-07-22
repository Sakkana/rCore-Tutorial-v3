# LibOS
> 对应 rCore-Tutorial-v3 第一章

## 用 rust + RISC-V 编写最小裸机可执行程序

### 创建项目
执行 
```zsh
rustc --version --verbose
```
可以看到如下输出

```zsh
rustc 1.73.0-nightly (399b06823 2023-07-20)
binary: rustc
commit-hash: 399b068235ceea440540539b3bfd1aeb82214a28
commit-date: 2023-07-20
host: x86_64-apple-darwin
release: 1.73.0-nightly
LLVM version: 16.0.5
```
观察到当前的 host 为 `x86_64-apple-darwin`

我也不知道为什么 mac 没有提供第四个参数，也就是运行时库。

编写一个最简单的 Helloworld
```rust
fn main() {
    println!("Hello, world!");
}
```

执行 `cargo run`，会正常编译并运行，可以看到如下输出。
```zsh
-<101:%>- cargo run
    Blocking waiting for file lock on package cache
    Finished dev [unoptimized + debuginfo] target(s) in 0.12s
     Running `target/debug/lib_os`
Hello, world!
```

### 编译至目标os为 none
如果使用 `cargo run --target riscv64gc-unknown-none-elf` 来编译

会出现以下错误 

```zsh
-<%>- cargo run --target riscv64gc-unknown-none-elf
   Compiling lib_os v0.1.0 (/Users/wuzhiyu/workshow/lib_os)
error[E0463]: can't find crate for `std`
  |
  = note: the `riscv64gc-unknown-none-elf` target may not support the standard library
  = note: `std` is required by `lib_os` because it does not declare `#![no_std]`
  = help: consider building the standard library from source with `cargo build -Zbuild-std`

error: cannot find macro `println` in this scope
 --> src/main.rs:2:5
  |
2 |     println!("Hello, world!");
  |     ^^^^^^^

error: `#[panic_handler]` function required, but not found

For more information about this error, try `rustc --explain E0463`.
error: could not compile `lib_os` (bin "lib_os") due to 3 previous errors
```

这是因为我们交叉编译并没有指定宿主操作系统，也就是第三个参数为 `none`。

编译参数有点长，每次都执行 `cargo run --target riscv64gc-unknown-none-elf` 有点搞。

可以讲这个参数写到配置文件里面。

在当前工程目录下执行
```zsh
mkdir .cargo 
echo '[build]\ntarget = "riscv64gc-unknown-none-elf"' > .cargo/config
```

将 `target` 参数写入配置文件，可以免去编译命令中手动输入参数的烦恼。

现在直接执行 `cargo run` 可以看到和之前一样的报错信息。

## rust 中移除标准库依赖
由于我们当前没有指定目标操作系统
> target = riscv64gc-unknown-**none**-elf

因此，需要移除标准库依赖。标准库是依赖于特定操作系统的。

解决措施：在 `main.rs` 开头加上 `#![no_std]`。

现在的程序变成了这样：
```rust
#![no_std]

fn main() {
    println!("Hello, world!");
}
```

`cargo run` 一下看看：
```rust
-<130:%>- cargo run
   Compiling lib_os v0.1.0 (/Users/wuzhiyu/workshow/lib_os)
error: cannot find macro `println` in this scope
 --> src/main.rs:4:5
  |
4 |     println!("Hello, world!");
  |     ^^^^^^^

error: `#[panic_handler]` function required, but not found

error: could not compile `lib_os` (bin "lib_os") due to 2 previous errors
```

std 错误消失了，但是其他的仍旧存在。

这个程序中 `println! 宏` 是由标准库 std 提供的。

他会使用一些宿主 os 提供的系统调用，因此直接把它注释掉吧。

```rust
#![no_std]

fn main() {
    // println!("Hello, world!");
}
```

run 一下，看到又少了一个错误。

### 添加 panic_handler 功能应对致命错误

创建新的文件 `src/lang_items.rs`
```rust
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
```

在 `src/main.rs` 添加一行
```rust
mod lang_items;
```

重新编译一下，前面的错误都消失了，但是多了个错误：
```rust
-<%>- cargo run
   Compiling lib_os v0.1.0 (/Users/wuzhiyu/workshow/lib_os)
error: requires `start` lang_item

error: could not compile `lib_os` (bin "lib_os") due to previous error
```

### 移除 main 函数

`start` 是编译器调用的，它会被标准库实现，用来做一些 `main` 函数开始前的初始化工作。

我们移除了标准库，start 自然没有人去实现了。

在 `src/main.rs` 前面加上一行。
```rust
#![no_main]
```

再次编译：
```zsh
-<101:%>- cargo run
   Compiling lib_os v0.1.0 (/Users/wuzhiyu/workshow/lib_os)
    Finished dev [unoptimized + debuginfo] target(s) in 0.75s
     Running `target/riscv64gc-unknown-none-elf/debug/lib_os`
target/riscv64gc-unknown-none-elf/debug/lib_os: target/riscv64gc-unknown-none-elf/debug/lib_os: cannot execute binary file
```

编译终于过了。

但是这个程序...似乎没有任何用。

没有任何功能，没有使用标准库，甚至连 main 函数都没有。

### 分析产生的二进制文件

分析一下刚才生成的二进制文件，需要先安装工具链：
```zsh
cargo install cargo-binutils
rustup component add llvm-tools-preview
```
查看刚才生成的目标文件：
```zsh
-<%>- file target/riscv64gc-unknown-none-elf/debug/lib_os
target/riscv64gc-unknown-none-elf/debug/lib_os: ELF 64-bit LSB executable, UCB RISC-V, version 1 (SYSV), statically linked, with debug_info, not stripped
```
```zsh
-<1:%>- rust-readobj -h target/riscv64gc-unknown-none-elf/debug/lib_os

File: target/riscv64gc-unknown-none-elf/debug/lib_os
Format: elf64-littleriscv
Arch: riscv64
AddressSize: 64bit
LoadName: <Not found>
ElfHeader {
  Ident {
    Magic: (7F 45 4C 46)
    Class: 64-bit (0x2)
    DataEncoding: LittleEndian (0x1)
    FileVersion: 1
    OS/ABI: SystemV (0x0)
    ABIVersion: 0
    Unused: (00 00 00 00 00 00 00)
  }
  Type: Executable (0x2)
  Machine: EM_RISCV (0xF3)
  Version: 1
  Entry: 0x0
  ProgramHeaderOffset: 0x40
  SectionHeaderOffset: 0x1AC8
  Flags [ (0x5)
    EF_RISCV_FLOAT_ABI_DOUBLE (0x4)
    EF_RISCV_RVC (0x1)
  ]
  HeaderSize: 64
  ProgramHeaderEntrySize: 56
  ProgramHeaderCount: 3
  SectionHeaderEntrySize: 64
  SectionHeaderCount: 14
  StringTableSectionIndex: 12
}
```

### 编写 open-sbi 引导后的第一条内核指令
创建rv汇编源代码
```zsh
touch ./src/entry.asm
```

这里只有一条指令——将立即数 `100` 载入 `x1` 寄存器 
```rust
    .section .text.entry
    .globl _start

_start:
li x1, 100
```

### 编写链接脚本
```ld
OUTPUT_ARCH(riscv)

ENTRY(_start)

BASE_ADDRESS = 0x80200000;

SECTIONS
{
    . = BASE_ADDRESS;
    skernel = .;

    stext = .;
    .text : {
        *(.text.entry)
        *(.text .text.*)
    }


    . = ALIGN(4K);
    etext = .;
    srodata = .;
    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    }


    . = ALIGN(4K);
    erodata = .;
    sdata = .;
    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }


    . = ALIGN(4K);
    edata = .;
    .bss : {
        *(.bss.stack)
        sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
    }


    . = ALIGN(4K);
    ebss = .;
    ekernel = .;

    /DISCARD/ : {
        *(.eh_frame)
    }
}
```


### 编译内核
```zsh
cargo build --release
```
编译出来的 elf 二进制在 ./target/$(ARCH)/release/lib_os


### 手动制作内核可执行程序
```zsh
rust-objcopy --strip-all target/riscv64gc-unknown-none-elf/release/lib_os -O binary target/riscv64gc-unknown-none-elf/release/lib_os.bin
```
这会生成一个剥离了 elf metadata 的纯指令二进制，这样子 qemu 就可以在该镜像的起始地址处找到我们的第一条指令。

两者区别：
```zsh
-<1:%>- rust-readobj lib_os    

File: lib_os
Format: elf64-littleriscv
Arch: riscv64
AddressSize: 64bit
LoadName: <Not found>

-<%>- rust-readobj lib_os.bin
xxx/bin/llvm-readobj: error: 'lib_os.bin': The file was not recognized as a valid object file
```

### 启动 qemu，加载内核镜像
`-s` 可以使 Qemu 监听本地 TCP 端口 1234 等待 GDB 客户端连接

`-S` 可以使 Qemu 在收到 GDB 的请求后再开始运行
```zsh
qemu-system-riscv64 \
    -machine virt \
    -nographic \
    -bios ./bootloader/rustsbi-qemu.bin \
    -device loader,file=target/riscv64gc-unknown-none-elf/release/lib_os.bin,addr=0x80200000 \
    -s -S
```

MAC 需要先安装 RISC-V 工具链
```zsh
brew tap riscv/riscv    
brew install riscv-tools
```

打开另一个 terminal，启动 gdb 连接
```zsh
riscv64-unknown-elf-gdb \
    -ex 'file target/riscv64gc-unknown-none-elf/release/lib_os' \
    -ex 'set arch riscv:rv64' \
    -ex 'target remote localhost:1234'
```

下面就进入了 gdb 调试。

### gdb 调试 qemu 启动流程
```zsh
-<%>- bash gdb.sh   
GNU gdb (SiFive GDB 8.3.0-2020.04.1) 8.3
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

(省略一些输出...)

warning: Architecture rejected target-supplied description
0x0000000000001000 in ?? ()
(gdb) 
```

可以看到，gdb 停在了 `0x1000` 这个地址处。
> QEMU 启动流程
> 1. 从 0x1000 开始。\
> 将可执行文件载入内存之后，qemu 的 PC 会被设置为 `0x1000`，执行没几行指令之后便会执行无条件跳转到 0x80000000。
> 2. 从 0x8000000 开始。\
> 这个地址是写死在 qemu 源代码里的，在不动 qemu 源代码的情况下我们的可执行二进制必须放在这个地址来启动。\
> 这个地址放的就是 RustSBI 程序，作为二段跳的引领者。
> 3. 从 0x80200000 开始。\
> 这个地址是 RustSBI 规定的，如果自己写一个 bootloader 可以自己指定这个阶段的起始地址。\
> 该阶段主要就是个性化的引导内核了。\
> 在这里，我们的内核只有一条指令。

在 gdb 中执行 `x/10i $pc`，告诉 gdb 我们要从当前 PC 值的位置开始，在内存中反汇编 10 条指令。
```gdb
(gdb) x/10i $pc
=> 0x1000:	auipc	t0,0x0
   0x1004:	addi	a2,t0,40
   0x1008:	csrr	a0,mhartid
   0x100c:	ld	a1,32(t0)
   0x1010:	ld	t0,24(t0)
   0x1014:	jr	t0
   0x1018:	unimp
   0x101a:	0x8000
   0x101c:	unimp
   0x101e:	unimp
```
可以看到在 `0x1014` 有一条很牛逼的指令，叫做 `jr	t0`。
`jr` 是一个伪指令，实际是对 `jalr` 的封装。

使用 `si` 单步一直到这个地址处。

```gdb
(gdb) si
0x0000000000001004 in ?? ()
(gdb) si
0x0000000000001008 in ?? ()
(gdb) si
0x000000000000100c in ?? ()
(gdb) si
0x0000000000001010 in ?? ()
(gdb) si
0x0000000000001014 in ?? ()
```

现在 PC 已经到了目的地，查看一下
```gdb
(gdb) print $pc
$1 = (void (*)()) 0x1014
(gdb) x/1i $pc
=> 0x1014:	jr	t0
```

当前指令就是跳转指令，现在跳过去吧。
```gdb
(gdb) si
0x0000000080000000 in ?? ()
```

果不其然，qemu 在初始化结束后会立刻跳到前面所说的 `0x8000000`。

看看这里有什么。

```gdb
(gdb) x/10i $pc
=> 0x80000000:	auipc	ra,0x2
   0x80000004:	jalr	834(ra)
   0x80000008:	auipc	ra,0x0
   0x8000000c:	jalr	116(ra)
   0x80000010:	j	0x80001690
   0x80000014:	unimp
   0x80000016:	addi	sp,sp,-80
   0x80000018:	sd	ra,72(sp)
   0x8000001a:	ld	a1,40(a0)
```

这里就是 RustSBI 的地盘了，不做细纠，直接到 RustSBI 继续我们的自由空间。
```gdb
(gdb) b *0x80200000
Breakpoint 4 at 0x80200000
(gdb) c
Continuing.

Breakpoint 4, 0x0000000080200000 in ?? ()
(gdb) print $pc
$2 = (void (*)()) 0x80200000
```
现在我们来到了我们内核的入口，看看我们的孤儿指令在不在这里。
```gdb
(gdb) x/10i $pc
=> 0x80200000:	li	ra,100
   0x80200004:	unimp
   0x80200006:	unimp
   0x80200008:	unimp
   0x8020000a:	unimp
   0x8020000c:	unimp
   0x8020000e:	unimp
   0x80200010:	unimp
   0x80200012:	unimp
   0x80200014:	unimp
```

果然这里只有一条指令，也恰恰是我们之前写的那一条。

查看一下当前 ra 寄存器里是啥。（查收册知道 ra 就是 x1，别名）
```gdb
(gdb) p/d $x1
$2 = 2147495338
```

继续往下执行一条。
```gdb
(gdb) si
0x0000000080200004 in ?? ()
(gdb) p/d $x1
$3 = 100
```

符合预期，100被装进了 ra 寄存器。

验证成功。