Pod::Spec.new do |s|
    s.name           = 'Bluepill'
    s.version        = `echo $(git describe --always --tags | cut -c 2-)`
    s.summary        = 'A tool to run iOS tests in parallel using multiple simulators.'
    s.homepage       = 'https://github.com/linkedin/bluepill'
    s.license        = { type: 'BSD', file: 'LICENSE' }
    s.author         = 'LinkedIn Corporation'
    s.source         = { http: "#{s.homepage}/releases/download/v#{s.version}/Bluepill-v#{s.version}.zip" }
    s.preserve_paths = '*'
    s.prepare_command = <<-CMD
                        ls -l
                        cp -r Bluepill-v#{s.version}/* ./
                        rm -rf Bluepill-v#{s.version}
                        CMD
  end
