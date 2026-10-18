-- Harness: run uosc's main.lua under a fake mpv and exercise the EOF guard.
package.path = '../src/uosc/?.lua;../src/uosc/?/init.lua;' .. package.path

local props, commands, observers, event_handlers, timers = {}, {}, {}, {}, {}

mp = {
	get_property_native = function(n) return props[n] end,
	set_property_native = function(n, v) props[n] = v end,
	set_property = function(n, v) props[n] = v end,
	get_property = function(n) return props[n] end,
	commandv = function(...)
		commands[#commands + 1] = table.concat({...}, ' ')
	end,
	command = function(c) commands[#commands + 1] = c end,
	observe_property = function(n, _, cb) observers[n] = cb end,
	register_event = function(n, cb)
		event_handlers[n] = event_handlers[n] or {}
		table.insert(event_handlers[n], cb)
	end,
	add_timeout = function(d, fn)
		local t = {timeout = d, fn = fn, killed = false}
		t.kill = function(s) s.killed = true end
		t.resume = function(s) s.killed = false end
		t.is_enabled = function(s) return not s.killed end
		timers[#timers + 1] = t
		return t
	end,
	add_periodic_timer = function(d, fn) return mp.add_timeout(d, fn) end,
	get_time = function() return os.clock() end,
	format_time = function(t) return string.format('%.2f', t or 0) end,
	create_osd_overlay = function() return {update = function() end} end,
	add_key_binding = function() end,
	get_script_directory = function() return '../src/uosc' end,
	get_script_name = function() return 'uosc' end,
	osd_message = function() end,
	set_osd_ass = function() end,
	set_key_bindings = function() end,
	register_script_message = function() end,
	unregister_script_message = function() end,
	command_native = function(c) return c[2] end,
}

package.preload['mp.assdraw'] = function()
	local base = {text = '', append = function() end}
	local function obj() return setmetatable({}, {__index = base}) end
	return {new = obj, ass_new = obj}
end
package.preload['mp.utils'] = function()
	return {
		file_info = function(p)
			local f = io.open(p, 'r')
			if not f then return nil end
			f:close()
			return {is_file = true}
		end,
		join_path = function(a, b) return a .. '/' .. b end,
	}
end
package.preload['mp.options'] = function() return {read_options = function() end} end
package.preload['mp.msg'] = function()
	return {error = function() end, warn = function() end, info = function() end, verbose = function() end}
end

dofile('../src/uosc/main.lua')

local uosc_state = state

local function fire(name, ...)
	for _, cb in ipairs(event_handlers[name] or {}) do cb(...) end
end

-- `state` mirrors props through uosc's own observers, so setting a prop through
-- the observer already updates `state`. Nothing else to sync.
local function set(name, value)
	props[name] = value
	local cb = observers[name]
	if cb then cb(name, value) end
end

-- Timers are one-shot in mpv: mark them spent once they have run.
local function flush_timers()
	for _ = 1, 5 do
		local live = false
		for _, t in ipairs(timers) do
			if not t.spent and not t.killed and t.fn then
				t.spent = true
				t.fn()
				live = true
			end
		end
		if not live then break end
	end
end

-- Commands issued synchronously by an observer (before `report` is called) are
-- just as much a result of the step, so collect everything since the last one.
local mark = #commands
local function report(label)
	local before = mark
	mark = #commands
	flush_timers()
	mark = #commands
	local out = {}
	for i = before + 1, #commands do out[#out + 1] = commands[i] end
	print(string.format('%-46s -> %s', label, #out > 0 and table.concat(out, ' | ') or '(nothing)'))
end

-- A 600s file of which only 0..100s is buffered.
props['path'] = '/media/movie.mkv'
props['playback-time'] = 100
props['demuxer-cache-state'] = {['eof-cached'] = false, ['seekable-ranges'] = {{['start'] = 0, ['end'] = 100}}}
props['eof-reached'] = false
fire('file-loaded')
set('duration', 600)
set('playback-time', 100)
props['osd-visible'] = true

print('== 0: playing inside the cache ==')
set('playback-time', 50)
report('time=50 (cached)')

print('== 1: EOF while only part of the file is buffered ==')
props['eof-reached'] = true
set('eof-reached', true)
report('eof-reached=true, cache=0..100')

print('== 2: seek past the buffered data, still inside the file ==')
props['eof-reached'] = false
set('eof-reached', false)
set('playback-time', 300)
fire('seek')
report('time=300 (cache ends at 100)')

print('== 3: seek back into the cache ==')
set('playback-time', 80)
fire('seek')
report('time=80 (cached)')

print('== 4: EOF with the whole file buffered, well before the end ==')
set('playback-time', 595)
props['demuxer-cache-state'] = {['eof-cached'] = true, ['seekable-ranges'] = {{['start'] = 0, ['end'] = 600}}}
props['eof-reached'] = true
set('eof-reached', true)
report('eof-reached=true, cache=0..600, time=595')

print('== 5: seek to the very end of the file ==')
props['eof-reached'] = false
set('eof-reached', false)
set('playback-time', 600)
fire('seek')
report('time=600 == duration')

print('== 6: a second file starts fresh ==')
props['path'] = '/media/other.mkv'
props['playback-time'] = 10
props['duration'] = 120
props['demuxer-cache-state'] = {['eof-cached'] = true, ['seekable-ranges'] = {{['start'] = 0, ['end'] = 120}}}
props['eof-reached'] = false
fire('file-loaded')
set('duration', 120)
set('playback-time', 10)
set('playback-time', 119)
report('other.mkv time=119 (cached, no notice)')
