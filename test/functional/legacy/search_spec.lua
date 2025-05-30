local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local feed = n.feed
local fn = n.fn
local poke_eventloop = n.poke_eventloop
local exec = n.exec

describe('search cmdline', function()
  local screen

  before_each(function()
    clear()
    command('set nohlsearch inccommand=')
    screen = Screen.new(20, 3)
  end)

  local function tenlines()
    fn.setline(1, {
      '  1',
      '  2 these',
      '  3 the',
      '  4 their',
      '  5 there',
      '  6 their',
      '  7 the',
      '  8 them',
      '  9 these',
      ' 10 foobar',
    })
    command('1')
  end

  it('history can be navigated with <C-N>/<C-P>', function()
    tenlines()
    command('set noincsearch')
    feed('/foobar<CR>')
    feed('/the<CR>')
    eq('the', eval('@/'))
    feed('/thes<C-P><C-P><CR>')
    eq('foobar', eval('@/'))
  end)

  describe('can traverse matches', function()
    before_each(tenlines)
    local function forwarditer(wrapscan)
      command('set incsearch ' .. wrapscan)
      feed('/the')
      screen:expect([[
          1                 |
          2 {2:the}se           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          2 these           |
          3 {2:the}             |
        /the^                |
      ]])
      eq({ 0, 0, 0, 0 }, fn.getpos('"'))
      feed('<C-G>')
      screen:expect([[
          3 the             |
          4 {2:the}ir           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          4 their           |
          5 {2:the}re           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          5 there           |
          6 {2:the}ir           |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          6 their           |
          7 {2:the}             |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          7 the             |
          8 {2:the}m            |
        /the^                |
      ]])
      feed('<C-G>')
      screen:expect([[
          8 them            |
          9 {2:the}se           |
        /the^                |
      ]])
      screen.bell = false
      feed('<C-G>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            2 {2:the}se           |
            3 the             |
          /the^                |
        ]])
      else
        screen:expect {
          grid = [[
            8 them            |
            9 {2:the}se           |
          /the^                |
        ]],
          condition = function()
            eq(true, screen.bell)
          end,
        }
        feed('<CR>')
        eq({ 0, 0, 0, 0 }, fn.getpos('"'))
      end
    end

    local function backiter(wrapscan)
      command('set incsearch ' .. wrapscan)
      command('$')

      feed('?the')
      screen:expect([[
          9 {2:the}se           |
         10 foobar          |
        ?the^                |
      ]])
      screen.bell = false
      if wrapscan == 'wrapscan' then
        feed('<C-G>')
        screen:expect([[
            2 {2:the}se           |
            3 the             |
          ?the^                |
        ]])
        feed('<CR>')
        screen:expect([[
            2 ^these           |
            3 the             |
          ?the                |
        ]])
      else
        feed('<C-G>')
        screen:expect {
          grid = [[
            9 {2:the}se           |
           10 foobar          |
          ?the^                |
        ]],
          condition = function()
            eq(true, screen.bell)
          end,
        }
        feed('<CR>')
        screen:expect([[
            9 ^these           |
           10 foobar          |
          ?the                |
        ]])
      end
      command('$')
      feed('?the')
      screen:expect([[
          9 {2:the}se           |
         10 foobar          |
        ?the^                |
      ]])
      feed('<C-T>')
      screen:expect([[
          8 {2:the}m            |
          9 these           |
        ?the^                |
      ]])
      for i = 1, 6 do
        feed('<C-T>')
        -- Avoid sleep just before expect, otherwise expect will take the full
        -- timeout
        if i ~= 6 then
          screen:sleep(1)
        end
      end
      screen:expect([[
          2 {2:the}se           |
          3 the             |
        ?the^                |
      ]])
      screen.bell = false
      feed('<C-T>')
      if wrapscan == 'wrapscan' then
        screen:expect([[
            9 {2:the}se           |
           10 foobar          |
          ?the^                |
        ]])
      else
        screen:expect {
          grid = [[
            2 {2:the}se           |
            3 the             |
          ?the^                |
        ]],
          condition = function()
            eq(true, screen.bell)
          end,
        }
      end
    end

    it("using <C-G> and 'nowrapscan'", function()
      forwarditer('nowrapscan')
    end)

    it("using <C-G> and 'wrapscan'", function()
      forwarditer('wrapscan')
    end)

    it("using <C-T> and 'nowrapscan'", function()
      backiter('nowrapscan')
    end)

    it("using <C-T> and 'wrapscan'", function()
      backiter('wrapscan')
    end)
  end)

  it('expands pattern with <C-L>', function()
    tenlines()
    command('set incsearch wrapscan')

    feed('/the')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])
    feed('<C-L>')
    screen:expect([[
        1                 |
        2 {2:thes}e           |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        9 {2:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        2 {2:thes}e           |
        3 the             |
      /thes^               |
    ]])
    feed('<CR>')
    screen:expect([[
        2 ^these           |
        3 the             |
      /thes               |
    ]])

    command('1')
    command('set nowrapscan')
    feed('/the')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])
    feed('<C-L>')
    screen:expect([[
        1                 |
        2 {2:thes}e           |
      /thes^               |
    ]])
    feed('<C-G>')
    screen:expect([[
        9 {2:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    feed('<C-G><CR>')
    screen:expect([[
        9 ^these           |
       10 foobar          |
      /thes               |
    ]])
  end)

  it('reduces pattern with <BS> and keeps cursor position', function()
    tenlines()
    command('set incsearch wrapscan')

    -- First match
    feed('/thei')
    screen:expect([[
        3 the             |
        4 {2:thei}r           |
      /thei^               |
    ]])
    -- Match from initial cursor position when modifying search
    feed('<BS>')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])
    -- New text advances to next match
    feed('s')
    screen:expect([[
        1                 |
        2 {2:thes}e           |
      /thes^               |
    ]])
    -- Stay on this match when deleting a character
    feed('<BS>')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])
    -- Advance to previous match
    feed('<C-T>')
    screen:expect([[
        9 {2:the}se           |
       10 foobar          |
      /the^                |
    ]])
    -- Extend search to include next character
    feed('<C-L>')
    screen:expect([[
        9 {2:thes}e           |
       10 foobar          |
      /thes^               |
    ]])
    -- Deleting all characters resets the cursor position
    feed('<BS><BS><BS><BS>')
    screen:expect([[
        1                 |
        2 these           |
      /^                   |
    ]])
    feed('the')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])
    feed('\\>')
    screen:expect([[
        2 these           |
        3 {2:the}             |
      /the\>^              |
    ]])
  end)

  it('can traverse matches in the same line with <C-G>/<C-T>', function()
    fn.setline(1, { '  1', '  2 these', '  3 the theother' })
    command('1')
    command('set incsearch')

    -- First match
    feed('/the')
    screen:expect([[
        1                 |
        2 {2:the}se           |
      /the^                |
    ]])

    -- Next match, different line
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 {2:the} theother    |
      /the^                |
    ]])

    -- Next match, same line
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 the {2:the}other    |
      /the^                |
    ]])
    feed('<C-G>')
    screen:expect([[
        2 these           |
        3 the theo{2:the}r    |
      /the^                |
    ]])

    -- Previous match, same line
    feed('<C-T>')
    screen:expect([[
        2 these           |
        3 the {2:the}other    |
      /the^                |
    ]])
    feed('<C-T>')
    screen:expect([[
        2 these           |
        3 {2:the} theother    |
      /the^                |
    ]])

    -- Previous match, different line
    feed('<C-T>')
    screen:expect([[
        2 {2:the}se           |
        3 the theother    |
      /the^                |
    ]])
  end)

  it('keeps the view after deleting a char from the search', function()
    screen:try_resize(20, 6)
    tenlines()

    feed('/foo')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 {2:foo}bar          |
      /foo^                |
    ]])
    feed('<BS>')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 {2:fo}obar          |
      /fo^                 |
    ]])
    feed('<CR>')
    screen:expect([[
        6 their           |
        7 the             |
        8 them            |
        9 these           |
       10 ^foobar          |
      /fo                 |
    ]])
    eq({
      lnum = 10,
      leftcol = 0,
      col = 4,
      topfill = 0,
      topline = 6,
      coladd = 0,
      skipcol = 0,
      curswant = 4,
    }, fn.winsaveview())
  end)

  it('restores original view after failed search', function()
    screen:try_resize(40, 3)
    tenlines()
    feed('0')
    feed('/foo')
    screen:expect([[
        9 these                               |
       10 {2:foo}bar                              |
      /foo^                                    |
    ]])
    feed('<C-W>')
    screen:expect([[
        1                                     |
        2 these                               |
      /^                                       |
    ]])
    feed('<CR>')
    screen:expect([[
      /                                       |
      {9:E35: No previous regular expression}     |
      {6:Press ENTER or type command to continue}^ |
    ]])
    feed('<CR>')
    eq({
      lnum = 1,
      leftcol = 0,
      col = 0,
      topfill = 0,
      topline = 1,
      coladd = 0,
      skipcol = 0,
      curswant = 0,
    }, fn.winsaveview())
  end)

  -- oldtest: Test_search_cmdline4().
  it("CTRL-G with 'incsearch' and ? goes in the right direction", function()
    screen:try_resize(40, 4)
    command('enew!')
    fn.setline(1, { '  1 the first', '  2 the second', '  3 the third' })
    command('set laststatus=0 shortmess+=s')
    command('set incsearch')
    command('$')
    -- Send the input in chunks, so the cmdline logic regards it as
    -- "interactive".  This mimics Vim's test_override("char_avail").
    -- (See legacy test: test_search.vim)
    feed('?the')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 the second                          |
        3 ^the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 ^the first                           |
        2 the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<c-g>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 ^the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 ^the first                           |
        2 the second                          |
        3 the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 the second                          |
        3 ^the third                           |
      ?the                                    |
    ]])

    command('$')
    feed('?the')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<c-t>')
    poke_eventloop()
    feed('<cr>')
    screen:expect([[
        1 the first                           |
        2 ^the second                          |
        3 the third                           |
      ?the                                    |
    ]])
  end)

  -- oldtest: Test_incsearch_sort_dump().
  it('incsearch works with :sort', function()
    screen:try_resize(20, 4)
    command('set incsearch hlsearch scrolloff=0')
    fn.setline(1, { 'another one 2', 'that one 3', 'the one 1' })

    feed(':sort ni u /on')
    screen:expect([[
      another {2:on}e 2       |
      that {10:on}e 3          |
      the {10:on}e 1           |
      :sort ni u /on^      |
    ]])
    feed('<esc>')
  end)

  -- oldtest: Test_incsearch_vimgrep_dump().
  it('incsearch works with :vimgrep family', function()
    screen:try_resize(30, 4)
    command('set incsearch hlsearch scrolloff=0')
    fn.setline(1, { 'another one 2', 'that one 3', 'the one 1' })

    feed(':vimgrep on')
    screen:expect([[
      another {2:on}e 2                 |
      that {10:on}e 3                    |
      the {10:on}e 1                     |
      :vimgrep on^                   |
    ]])
    feed('<esc>')

    feed(':vimg /on/ *.txt')
    screen:expect([[
      another {2:on}e 2                 |
      that {10:on}e 3                    |
      the {10:on}e 1                     |
      :vimg /on/ *.txt^              |
    ]])
    feed('<esc>')

    feed(':vimgrepadd "\\<LT>on')
    screen:expect([[
      another {2:on}e 2                 |
      that {10:on}e 3                    |
      the {10:on}e 1                     |
      :vimgrepadd "\<on^             |
    ]])
    feed('<esc>')

    feed(':lv "tha')
    screen:expect([[
      another one 2                 |
      {2:tha}t one 3                    |
      the one 1                     |
      :lv "tha^                      |
    ]])
    feed('<esc>')

    feed(':lvimgrepa "the" **/*.txt')
    screen:expect([[
      ano{2:the}r one 2                 |
      that one 3                    |
      {10:the} one 1                     |
      :lvimgrepa "the" **/*.txt^     |
    ]])
    feed('<esc>')
  end)

  -- oldtest: Test_incsearch_substitute_dump2()
  it('incsearch detects empty pattern properly vim-patch:8.2.2295', function()
    screen:try_resize(70, 6)
    exec([[
      set incsearch hlsearch scrolloff=0
      for n in range(1, 4)
        call setline(n, "foo " . n)
      endfor
      call setline(5, "abc|def")
      3
    ]])

    feed([[:%s/\vabc|]])
    screen:expect([[
      foo 1                                                                 |
      foo 2                                                                 |
      foo 3                                                                 |
      foo 4                                                                 |
      abc|def                                                               |
      :%s/\vabc|^                                                            |
    ]])
    feed('<Esc>')

    -- The following should not be highlighted
    feed([[:1,5s/\v|]])
    screen:expect([[
      foo 1                                                                 |
      foo 2                                                                 |
      foo 3                                                                 |
      foo 4                                                                 |
      abc|def                                                               |
      :1,5s/\v|^                                                             |
    ]])
  end)

  -- oldtest: Test_incsearch_restore_view()
  it('incsearch restores viewport', function()
    screen:try_resize(20, 6)
    exec([[
      set incsearch nohlsearch
      setlocal scrolloff=0 smoothscroll
      call setline(1, [join(range(25), ' '), '', '', '', '', 'xxx'])
      call feedkeys("2\<C-E>", 't')
    ]])
    local s = [[
      {1:<<<} 18 19 20 21 22 2|
      ^3 24                |
                          |*4
    ]]
    screen:expect(s)
    feed('/xx')
    screen:expect([[
                          |*4
      {2:xx}x                 |
      /xx^                 |
    ]])
    feed('x')
    screen:expect([[
                          |*4
      {2:xxx}                 |
      /xxx^                |
    ]])
    feed('<Esc>')
    screen:expect(s)
  end)
end)

describe('Search highlight', function()
  before_each(clear)

  -- oldtest: Test_hlsearch_dump()
  it('beyond line end vim-patch:8.2.2542', function()
    local screen = Screen.new(50, 6)
    exec([[
      set hlsearch noincsearch cursorline
      call setline(1, ["xxx", "xxx", "xxx"])
      /.*
      2
    ]])
    feed([[/\_.*<CR>]])
    screen:expect([[
      {10:xxx }                                              |*2
      {10:^xxx }{21:                                              }|
      {1:~                                                 }|*2
      /\_.*                                             |
    ]])
  end)

  -- oldtest: Test_hlsearch_and_visual()
  it('is combined with Visual highlight vim-patch:8.2.2797', function()
    local screen = Screen.new(40, 6)
    screen:add_extra_attr_ids {
      [100] = {
        foreground = Screen.colors.Black,
        bold = true,
        background = Screen.colors.LightGrey,
      },
      [101] = { bold = true, background = Screen.colors.Yellow },
    }
    exec([[
      set hlsearch noincsearch
      call setline(1, repeat(["xxx yyy zzz"], 3))
      hi Search gui=bold
      /yyy
      call cursor(1, 6)
    ]])
    feed('vjj')
    screen:expect([[
      xxx {101:y}{100:yy}{17: zzz}                             |
      {17:xxx }{100:yyy}{17: zzz}                             |
      {17:xxx }{100:y}{101:^yy} zzz                             |
      {1:~                                       }|*2
      {5:-- VISUAL --}                            |
    ]])
  end)
end)
