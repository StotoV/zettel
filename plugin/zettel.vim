let g:zettel_dir = '~/.zettel'

function! CreateZettel
    python << EOF
        import vim
        import string
        import random

        letters = string.ascii_lowercase
        random_id = ''.join(random.choice(letters) for i in range(RANDOM_TITLE_LENGTH))
        with open(vim.eval('&zettel_dir') + '/' + random_id + '_' + title, 'x') as zettel:
            zettel.writelines(title)
            zettel.writelines('-'*100)
            zettel.writelines('')
            zettel.writelines('')
            zettel.writelines('-'*5 + ' External references ' + '-'*74)
            zettel.writelines('')
            zettel.writelines('-'*100)
            zettel.writelines('*Date:*  ')
            zettel.writelines('*Tags:*  ')
            zettel.writelines('*Backlinks:*  ')
    EOF

