'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('hello', 'Hello 演示',
			'这是一个最小可用的自定义插件骨架。改完重新编译即可出现在菜单里。');

		s = m.section(form.NamedSection, 'main', 'hello', '基本设置');
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', '启用');
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'message', '问候语',
			'演示用：改完点保存，配置会写进 /etc/config/hello');
		o.default = '你好，路由器';
		o.rmempty = false;

		return m.render();
	}
});
