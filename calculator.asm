; “A”——“+”
; “B”——“-”
; “C”——“*” 
; “D”——“括号” 
; “E”——“=” 
; “F”——开始运算（包括撤消运算），屏幕显示“0”。
;
; 运算要求： 
;     ⑴ 输入待计算数据（小于四位数），数码管跟随显示。 
;     ⑵ 按“+”、“-”、“*”或“括号”时，当前显示内容不变。 
;     ⑶ 再输入数据时，数码管跟随显示。 
;     ⑷ 按“E”时，显示最终结果数据。若计算结果为奇数，则点亮1个红色发光二极管，并持续以1秒间
;     隔（硬件实现）闪烁；若计算结果为偶数，则点亮2个绿色发光二极管，并持续以2秒间隔（硬件实现）闪
;     烁。 
;     ⑸ 按“F”键：左侧四个数码管中最右边（对应个位数）的一个显示“0”，其余三个不显示内容。
;     同时熄灭点亮的发光二极管，等待下一次运算的开始。 
;     ⑹ 需要考虑运算的优先级问题。 
;     ⑺ 可以只考虑正整数运算，不考虑负数和实数运算。括号可以不考虑嵌套情况，但必须能实现算式
;     中存在多组平行括号的计算。
;
; 设计说明： 
;     输入数据时，若超出显示范围则不响应超出部分。在计算结果超出显示范围时，则显示“F”。


code    segment
        assume cs:code

org  1000h

    ; 中断控制器 8259
    ; 8259只处理来自8253的计时中断
    port59_0    equ 0ffe4h
    port59_1    equ 0ffe5h
    icw1        equ 13H         ; 边沿触发
    icw2        equ 08h         ; 中断类型号 08H 09H ...
    icw4        equ 09h         ; 全嵌套，非缓冲，非自动EOI，8086/88模式
    ocw1open    equ 07fh        ; IRQ7，类型号为0fh，向量地址偏移地址3ch，段地址0，参考示例第13行 
    ocw1down    equ 0ffh

    ; 并行接口芯片 8255
    ; 8255向led灯输出led状态
    port55_a    equ 0ffd8H
    port55_ctrl equ 0ffdBH

    ; 计数定时芯片 8253
    port53_0    equ 0ffe0H
    port53_ctrl equ 0ffe3H      ; 控制口
    count_1sec  equ 19200       ; 1s计数次数
    count_2sec  equ 38400       ; 2s计数次数


    led_status              db 6 dup(?)
    led_count               db 0
    previous_key            db 20h
    current_key             db 20h
    has_previous_bracket    db 0
    same_as_pre             db 0

    operand_stack_base      db ? ;TODO
    operator_stack_base     db ? ;TODO
    operand_stack_ptr       db ? ;TODO
    operator_stack_ptr      db ? ;TODO
    operator_stack_top      db ?
    operator_next           db '#'

    result                  db 0
    led_overflow            db 0
    error                   db 0

    OUTSEG  equ  0ffdch             ;段控制口
    OUTBIT  equ  0ffddh             ;位控制口/键扫口
    IN_KEY  equ  0ffdeh             ;键盘读入口
    ;八段管显示码
    LedMap  db   0c0h,0f9h,0a4h,0b0h,099h,092h,082h,0f8h
            db   080h,090h,088h,083h,0c6h,0a1h,086h,08eh
    ;键码定义
    KeyTable db   07h,04h,08h,05h,09h,06h,0ah,0bh
            db   01h,00h,02h,0fh,03h,0eh,0ch,0dh


; start
    cli
    call init_all
main:
    sti
    call get_key
    call handle_key
    jmp main
; end



init_all proc
        call init8259
        call init8255
        call init8253
        call init_stack
        call clean_led
        ret
init_all endp


init8259 proc
        push ax
        push dx
        mov dx, port59_0
        mov al, icw1
        out dx, al
        mov dx, port59_1
        mov al, icw2
        mov dx, port59_1
        out dx, al
        mov al, icw4
        out dx, al
        mov al, ocw1down
        out dx, al
        pop dx
        pop ax
        ret
init8259 endp


init8255 proc
        push ax
        push dx
        mov dx, port55_ctrl
        mov al, 88H
        out dx, al
        mov al, lightOff
        mov dx, port55_a
        out dx, al
        pop dx
        pop ax
        ret
init8255 endp


init8253 proc
        push dx
        push ax
        mov dx, port53_ctrl
        mov al, 30H            ; 计数器0，先低8位，再高8位，方式0，二进制计数
        out dx, al
        pop ax
        pop dx
        ret
init8253 endp


init_stack proc
        ; TODO init operand stack
        ; TODO init operator stack
init_stack endp


clean_all proc
        call init_stack
clean_all endp


clean_led proc
        ; TODO 最后一位显示0，其余不显示
clean_led endp


get_key proc                    ;键扫子程序
    ; store key in current_key
        push ax
        push bx
        push cx
        push dx

        mov al, current_key     ;上一次扫描的符号
        mov previous_key, al

        mov  al,0ffh            ;关显示口
        mov  dx,OUTSEG
        out  dx,al
        mov  bl,0
        mov  ah,0feh
        mov  cx,8
    key1:   
        mov  al,ah
        mov  dx,OUTBIT
        out  dx,al
        shl  al,1
        mov  ah,al
        nop
        nop
        nop
        nop
        nop
        nop
        mov  dx,IN_KEY
        in   al,dx
        not  al
        nop
        nop
        and  al,0fh
        jnz  key2
        inc  bl
        loop key1
    nkey:   
        mov  al,20h
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
    key2:   
        test al,1
        je   key3
        mov  al,0
        jmp  key6
    key3:   
        test al,2
        je   key4
        mov  al,8
        jmp  key6
    key4:   
        test al,4
        je   key5
        mov  al,10h
        jmp  key6
    key5:   
        test al,8
        je   nkey
        mov  al,18h
    key6:   
        add  al,bl
        cmp  al,10h
        jnc  fkey
        mov  bx,offset KeyTable
        xlat
    fkey:   
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
get_key endp


handle_key proc
        call is_same_as_pre
        cmp same_as_pre, 1
        jne handle_key_continue
        call do_nothing ; TODO
        ret
    handle_key_continue:
        cmp al, 10
        jnb handle_key_a
        call handle_number
        ret
    handle_key_a:
        cmp al, 0ah
        jne handle_key_b
        call handle_a
        ret
    handle_key_b:
        cmp al, 0bh
        jne handle_key_c
        call handle_b
        ret
    handle_key_c:
        cmp al, 0ch
        jne handle_key_d
        call handle_c
        ret
    handle_key_d:
        cmp al, 0dh
        jne handle_key_e
        call handle_d
        ret
    handle_key_e:
        cmp al, 0eh
        jne handle_key_f
        call handle_a
        ret
    handle_key_f:
        cmp al, 0fh
        call handle_error
        ret
handle_key endp

is_same_as_pre proc
    ;给same_as_pre赋值
    push ax
    mov al, current_key
    cmp al, previous_key
    je is_same
    mov same_as_pre, 0
    jmp return
is_same: 
    mov same_as_pre, 1
return:    
    pop ax
    ret
is_same_as_pre endp



handle_number proc
handle_number endp

handle_error proc
handle_error endp

handle_a proc
handle_a endp

handle_b proc
handle_b endp

handle_c proc
handle_c endp

handle_d proc
handle_d endp

handle_e proc
handle_e endp

handle_f proc
handle_f endp
