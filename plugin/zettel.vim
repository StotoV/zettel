if !has("python3")
    echo "vim has to be compiled with +python3 to run this"
    finish
endif

" Prevent loading multiple times
if exists("g:loaded_zettel_plugin")
    finish
endif
let g:loaded_zettel_plugin = 1

if !exists("g:zettel_dir")
    let g:zettel_dir = '~/.zettel'
endif

if !exists("g:zettel_random_title_length")
    let g:zettel_random_title_length = 5
endif

if !exists("g:zettel_fzf_fullscreen")
    let g:zettel_fzf_fullscreen = 0
endif

if !exists("g:zettel_extension")
    let g:zettel_extension = '.zettel'
endif

let s:current_file = expand('<sfile>:p:h')

" Expose commands
command! -nargs=1 CreateZettel call s:create_zettel(<f-args>)
command! -nargs=1 DeleteZettel call s:delete_zettel(<f-args>)
command! -nargs=0 SearchZettels call s:search_zettels()
command! -nargs=0 InsertZettelLink call s:insert_zettel_link()
command! -nargs=1 ProcessInsertLink call s:process_insert_link(<f-args>)
command! -nargs=1 CreateZettelInsertLink call s:create_zettel_insert_link(<f-args>)
command! -nargs=0 FollowLink call s:follow_link()
command! -nargs=0 ZettelGraph call s:graph()
command! -nargs=0 SetZDir call s:set_zettel_dir()

function! s:set_zettel_dir()
python3 << EOF
import os
from pathlib import Path

def set_path():
    path = os.getcwd()
    while path != '/':
        for directory in os.listdir(path):
            if directory == '.zettel':
                zettel_path = os.path.join(path, '.zettel')
                vim.command('let g:zettel_dir = "{}"'.format(zettel_path))
                return
        path = os.path.abspath(os.path.join(path, os.pardir))
set_path()
EOF
endfunction

function! s:graph()
    call s:set_zettel_dir()
python3 << EOF
import vim
import os
import re
import matplotlib
import matplotlib.pyplot as plt
from mpl_interactions import panhandler
from netgraph import InteractiveGraph
import networkx as nx
import types
from pathlib import Path

def extract_note_data(note_path):
    with open(note_path, 'r+') as note:
        note_title = next(note).replace('Title: ', '').strip()
        note_id = ''
        note_tags = []
        note_links = []

        for line in note:
            note_links += re.findall('\[([^\]]*\.'+ vim.eval('g:zettel_extension')[1:] +')\]', line)

            if line[:4] == 'ID: ':
                note_id = line.replace('ID: ', '').strip()+vim.eval('g:zettel_extension')

            if line[:6] == 'Tags: ':
                note_tags = set(list(filter(None, line.replace('Tags: ', '').strip().split(':'))))

        note_links = set(note_links)
        return {'title': note_title, 'id': note_id, 'tags': note_tags, 'links': note_links}


def build_graph():
    graph = nx.DiGraph()

    notes = Path(os.path.expanduser(vim.eval('g:zettel_dir'))).glob('*'+vim.eval('g:zettel_extension'))
    for note in notes:
        if os.path.getsize(note) > 0:
            note_data = extract_note_data(note)

            # print(graph.nodes)
            if note_data['id'] in graph.nodes:
                graph.nodes[note_data['id']]['label'] = note_data['title']
            else:
                graph.add_node(note_data['id'], color='blue', label=note_data['title'], shape='o')
            
            for tag in note_data['tags']:
                graph.add_node(tag, color='red', label=tag, shape='v')
                graph.add_edge(tag, note_data['id'])

            for link in note_data['links']:
                graph.add_node(link, color='green', shape='o')
                graph.add_edge(note_data['id'], link)

    for node in graph.nodes().keys():
        graph.nodes[node]['weight'] = len(graph.out_edges(node))

    return graph

def draw_graph(graph):
    plt.rcParams['toolbar'] = 'None'
    current_node = vim.eval("expand('%:t')")

    norm = matplotlib.colors.Normalize(
        vmin=min(nx.get_node_attributes(graph,"weight").values()),
        vmax=max(nx.get_node_attributes(graph,"weight").values())
    )
    color = matplotlib.cm.ScalarMappable(norm=norm, cmap=matplotlib.cm.plasma)
    node_colors = {}
    for node in graph.nodes().keys():
        if node == current_node:
            node_colors[node] = (1,0.1,0.1)
        else:
            node_colors[node] = color.to_rgba(graph.nodes[node]['weight'])

    plot_instance = InteractiveGraph(
        graph,
        node_layout='spring',
        node_size=1,
        node_color=node_colors,
        node_shape=nx.get_node_attributes(graph,"shape"),
        node_labels=nx.get_node_attributes(graph,"label"),
        node_label_fontdict={
            'size': 6,
            'verticalalignment': 'top',
            'clip_on': True,
            'color': (0.8,0.8,0.8)
        },
        # scale=(1,2),
        node_edge_width=0,
        node_zorder=2,
        edge_width=0.2,
        edge_color=(.5,.5,.5),
        edge_zorder=-1,
        # edge_layout='straight',
        edge_layout='curved',
        # edge_layout='bundled',
        arrows=True,
    )

    ax = plt.gca()
    ax.set_facecolor((0.1,0.1,0.1))
    ax.set_position([0, 0, 1, 1])
    ax.xaxis.label.set_color((1,1,1))
    ax.yaxis.label.set_color((1,1,1))

    fig = plt.gcf()
    fig.set_size_inches(50, 5, forward=True)
    fig.set_facecolor((0.2,0.2,0.2))
    fig.canvas.mpl_connect('scroll_event', mousewheel_move)
    fig.canvas.mpl_connect('button_press_event', lambda event: button_click(event, plot_instance))
    pan_handler = panhandler(fig)

    plt.tight_layout(pad=0)
    plt.show()

def button_click(event, plot_instance):
    if event.dblclick:
        x = event.xdata
        y = event.ydata
        for node_id, node in plot_instance.node_artists.items():
            dist = ((x-node.xy[0])**2 + (y-node.xy[1])**2)**0.5
            if dist < node.radius:
                zettel = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + node_id)
                vim.command('bd|e {}'.format(zettel))
                plt.close()

def mousewheel_move(event):
    ax=event.inaxes
    ax._pan_start = types.SimpleNamespace(
            lim=ax.viewLim.frozen(),
            trans=ax.transData.frozen(),
            trans_inverse=ax.transData.inverted().frozen(),
            bbox=ax.bbox.frozen(),
            x=event.x,
            y=event.y)
    if event.button == 'up':
        ax.drag_pan(3, event.key, event.x+30, event.y+30)
    else: #event.button == 'down':
        ax.drag_pan(3, event.key, event.x-30, event.y-30)
    fig=ax.get_figure()
    fig.canvas.draw_idle()

def main():
    graph = build_graph()
    draw_graph(graph)

main()
EOF
endfunction

function! s:create_zettel(title, openNow=1)
    call s:set_zettel_dir()
python3 << EOF
import vim
import string
import random
import os
from datetime import datetime

letters = string.ascii_lowercase
random_id = ''.join(random.choice(letters) for i in range(int(vim.eval('g:zettel_random_title_length'))))
zettel_path = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + \
                                 random_id + '_' + vim.eval('a:title') + vim.eval('g:zettel_extension'))
with open(zettel_path, 'x') as zettel:
    zettel.writelines('Title: ' + vim.eval('a:title') + '\n')
    zettel.writelines('-'*100 + '\n')
    zettel.writelines('\n')
    zettel.writelines('\n')
    zettel.writelines('-'*5 + ' External references ' + '-'*74 + '\n')
    zettel.writelines('\n')
    zettel.writelines('-'*100 + '\n')
    zettel.writelines('-'*5 + ' Metadata ' + '-'*84 + '\n')
    zettel.writelines('ID: ' + random_id + '_' + vim.eval('a:title') + '  \n')
    zettel.writelines('Date: ' + str(datetime.now()) + '  \n')
    zettel.writelines('Tags:' + ' \n')
    zettel.writelines('Backlinks:\n')

if vim.eval('a:openNow') == 1:
    vim.command('tabnew {}'.format(zettel_path))
EOF
    return py3eval('zettel_path')
endfunction

function! s:create_zettel_insert_link(title)
    let s:new_zettel_path = s:create_zettel(a:title, 1)
    call s:process_insert_link(s:new_zettel_path)
endfunction

function! s:delete_zettel(zettel)
    call s:set_zettel_dir()
python3 << EOF
import vim
import os

zettel_path = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + vim.eval('a:zettel'))
os.remove(zettel_path)
EOF
endfunction

function! s:search_zettels()
    call s:set_zettel_dir()
    let command = s:current_file .. '/ag_builder' .. ' %s %s'
    let initial_command = printf(command, '.', g:zettel_dir)
    let reload_command = printf(command, '{q}', g:zettel_dir)

    let spec = {'options': ['--phony', '--bind', 'change:reload:'.reload_command]}
    call fzf#vim#grep(initial_command, 0, fzf#vim#with_preview(spec), g:zettel_fzf_fullscreen)
endfunction

function! s:process_insert_link(search_result)
    call s:set_zettel_dir()
python3 << EOF
zettel_path = vim.eval('a:search_result').split(':')[0].split('/')[-1]
vim.command('exe "normal! a" . "[{}]"'.format(zettel_path))
backlink = vim.current.buffer.name.split(':')[0].split('/')[-1]
vim.command('call s:add_backlink("{}","{}")'.format(zettel_path, backlink))
EOF
endfunction

function! s:insert_zettel_link()
    call s:set_zettel_dir()
    let command = s:current_file .. '/ag_builder' .. ' %s %s'
    let initial_command = printf(command, '.', g:zettel_dir)
    let reload_command = printf(command, '{q}', g:zettel_dir)
    let spec = {'sink': 'ProcessInsertLink', 'options': ['--bind', 'change:reload:'.reload_command]}
    call fzf#vim#grep(initial_command, 0, fzf#vim#with_preview(spec), g:zettel_fzf_fullscreen)
endfunction

function! s:add_backlink(zettel, backlink)
    call s:set_zettel_dir()
python3 << EOF
import vim
import os

with open(os.path.expanduser(vim.eval('g:zettel_dir') + '/' + vim.eval('a:zettel')), 'a+') as f:
    zettel = f.read().splitlines()
    index = 0
    for i, line in enumerate(zettel):
        if line.startswith('----- Metadata'):
            index = i
            break

    if '[{}]'.format(vim.eval('a:backlink')) not in zettel[index:]:
        f.writelines('[{}]\n'.format(vim.eval('a:backlink')))
EOF
endfunction

function! s:follow_link()
    call s:set_zettel_dir()
python3 << EOF
import vim
import os

row, col = vim.current.window.cursor
line = vim.current.buffer[row-1]
low_point = high_point = None
for i in range(col, -1, -1):
    if line[i] == '[':
        low_point = i+1
for i in range(col, len(line)):
    if line[i] == ']':
        high_point = i

if low_point is None or high_point is None:
    raise ValueError('Invalid link')

zettel = os.path.expanduser(vim.eval('g:zettel_dir') + '/' + line[low_point:high_point])
vim.command('e {}'.format(zettel))
EOF
endfunction
