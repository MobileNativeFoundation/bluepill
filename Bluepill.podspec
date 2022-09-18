Pod::Spec.new do |s|
    s.name           = 'Bluepill'
    s.version        = `echo $(git describe --always --tags | cut -c 2-)`
    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '12.0'
    s.summary        = 'A tool to run iOS tests in parallel using multiple simulators.'
    s.homepage       = 'https://github.com/linkedin/bluepill'
    s.license        = { type: 'BSD', file: 'LICENSE' }
    s.author         = 'LinkedIn Corporation'
    s.source         = { http: "#{s.homepage}/releases/download/v#{s.version}/Bluepill-v#{s.version}.zip" }
    s.preserve_paths = '*'
    s.prepare_command = <<-CMD
                        mv Bluepill-v#{s.version}/* ./
                        rmdir Bluepill-v#{s.version}
                        CMD
  end
