#!/usr/bin/env python3
"""Fatal lint plus portable synthesis elaboration and clocked-memory checks."""
import json
import sys
from collections import Counter
from regress import ROOT,CPU,SOC,command

def number(x):
    return int(x,2) if isinstance(x,str) else x

def main(arty=False):
    board=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl'/'board').glob('*.sv'))]
    rtl=CPU+SOC+board
    target='arty_a7_top' if arty else 'fpga_top'
    prefix='arty_' if arty else ''
    if arty: rtl+=['boards/arty_a7_100t/arty_a7_top.sv']
    for top in ([target] if arty else ['fpga_top','led_test_top','uart_test_top']):
        command(['verilator','--lint-only','-Wall','--top-module',top,'scripts/lint.vlt',*rtl],f'build/lint_{top}.txt')
    if arty:
        for mode in [1,2]:
            command(['verilator','--lint-only','-Wall','--top-module',target,f'-GMODE={mode}','scripts/lint.vlt',*rtl],f'build/lint_arty_mode{mode}.txt')
    # Keep memory cells, proving clocked inference without exploding RAM into FFs.
    script='read_verilog -sv -DSYNTHESIS '+' '.join(rtl)+'\n'
    script+=f'hierarchy -check -top {target}\nproc\nopt\nmemory_dff\nmemory_collect\nopt\ncheck -assert\nstat\nwrite_json build/{prefix}synthesis.json\n'
    (ROOT/'build'/f'{prefix}synth.ys').write_text(script)
    command(['yosys','-Q','-T','-q','-l',f'build/{prefix}synthesis_full.txt','-s',f'build/{prefix}synth.ys'],f'build/{prefix}synthesis.txt')
    net=json.loads((ROOT/'build'/f'{prefix}synthesis.json').read_text())
    expected={'clk','reset_n','uart_rx','uart_tx','led'} if arty else {'clk','external_reset','uart_tx_pin','led'}
    assert set(net['modules'][target]['ports']) == expected, 'Unexpected physical interface'
    memories=[];multipliers=[]
    for name,mod in net['modules'].items():
        for cell_name,cell in mod.get('cells',{}).items():
            assert 'latch' not in cell['type'].lower(), f'Inferred latch: {name}.{cell_name}'
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
    (ROOT/'build'/f'{prefix}synthesis_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('PASS: fatal lint, synthesis check, two clocked 4096-word memories, one signed 8x8 multiplier')
    if arty:
        mapped_script=script.splitlines()[0]+'\nsynth_xilinx -family xc7 -top arty_a7_top\ncheck -assert\nstat -tech xilinx\nwrite_json build/arty_xilinx.json\n'
        (ROOT/'build'/'arty_xilinx.ys').write_text(mapped_script)
        command(['yosys','-Q','-T','-q','-l','build/arty_xilinx_full.txt','-s','build/arty_xilinx.ys'],'build/arty_xilinx.txt')
        modules=json.loads((ROOT/'build'/'arty_xilinx.json').read_text())['modules']
        def resources(name):
            found=Counter()
            for cell in modules[name].get('cells',{}).values():
                kind=cell['type']
                if kind in modules and modules[kind].get('cells'):
                    found.update(resources(kind))
                else:
                    assert not kind.startswith('$'), f'Unmapped synthesis cell {kind}'
                    found[kind]+=1
            return found
        counts=resources('arty_a7_top')
        assert counts['RAMB18E1']+counts['RAMB36E1']>0, 'No block RAM mapped'
        assert not any(k.startswith('LD') for k in counts), 'Mapped latch'
        summary={'scope':'Yosys 7-series synthesis mapping ONLY; not Vivado utilization or timing',
                 'primitive_counts':dict(sorted(counts.items()))}
        (ROOT/'build'/'arty_mapping_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(f"PASS: Yosys xc7 mapping; {counts['RAMB18E1']} RAMB18E1, {counts['RAMB36E1']} RAMB36E1, {counts['DSP48E1']} DSP48E1; no unmapped cells/latches")

if __name__=='__main__': main(arty='--arty' in sys.argv)
