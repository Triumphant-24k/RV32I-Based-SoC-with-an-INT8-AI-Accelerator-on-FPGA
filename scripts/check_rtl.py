#!/usr/bin/env python3
"""Fatal lint plus portable synthesis elaboration and clocked-memory checks."""
import json
from regress import ROOT,CPU,SOC,command

def number(x):
    return int(x,2) if isinstance(x,str) else x

def main():
    board=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl'/'board').glob('*.sv'))]
    rtl=CPU+SOC+board
    for top in ['fpga_top','led_test_top','uart_test_top']:
        command(['verilator','--lint-only','-Wall','--top-module',top,'scripts/lint.vlt',*rtl],f'build/lint_{top}.txt')
    # Keep memory cells, proving clocked inference without exploding RAM into FFs.
    script='read_verilog -sv -DSYNTHESIS '+' '.join(rtl)+'\n'
    script+='hierarchy -check -top fpga_top\nproc\nopt\nmemory_dff\nmemory_collect\nopt\ncheck -assert\nstat\nwrite_json build/synthesis.json\n'
    (ROOT/'build'/'synth.ys').write_text(script)
    command(['yosys','-Q','-T','-q','-l','build/synthesis_full.txt','-s','build/synth.ys'],'build/synthesis.txt')
    net=json.loads((ROOT/'build'/'synthesis.json').read_text())
    assert set(net['modules']['fpga_top']['ports']) == {'clk','external_reset','uart_tx_pin','led'}, 'Unexpected physical interface'
    memories=[];multipliers=[]
    for name,mod in net['modules'].items():
        for cell_name,cell in mod.get('cells',{}).items():
            if cell['type'] in ('$mem','$mem_v2'):
                p=cell['parameters'];size=number(p['SIZE']);width=number(p['WIDTH'])
                if size==4096:
                    ports=number(p['RD_PORTS']);clocks=number(p['RD_CLK_ENABLE'])
                    assert clocks==(1<<ports)-1, f'Asynchronous memory read: {name}.{cell_name}'
                    memories.append(dict(name=cell_name,words=size,width=width,clocked_read_ports=ports))
            if cell['type']=='$mul':
                p=cell['parameters']
                multipliers.append({key:number(p[key]) for key in ['A_WIDTH','B_WIDTH','Y_WIDTH','A_SIGNED','B_SIGNED']})
    assert len(memories)==2, f'Expected ROM and RAM block-memory candidates, got {memories}'
    assert len(multipliers)==1, f'Expected one MAC multiplier, got {multipliers}'
    assert multipliers[0]['A_WIDTH']==8 and multipliers[0]['B_WIDTH']==8
    assert multipliers[0]['A_SIGNED']==1 and multipliers[0]['B_SIGNED']==1
    summary=dict(scope='Portable Yosys process/memory synthesis, not placed/routed FPGA implementation',
                 memories=memories,multipliers=multipliers)
    (ROOT/'build'/'synthesis_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('PASS: fatal lint, synthesis check, two clocked 4096-word memories, one signed 8x8 multiplier')

if __name__=='__main__': main()
