# source set_classpath_for_jruby.sh

PROJ_HOME=$(cd $(dirname $0);pwd)
APPENGINE_SDK_GEM=/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0

CLASSPATH=""
CLASSPATH=$CLASSPATH:$PROJ_HOME/WEB-INF/lib/appengine-api-1.0-sdk-1.3.0.jar
CLASSPATH=$CLASSPATH:$PROJ_HOME/WEB-INF/lib/appengine-api-labs-1.3.0.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-1.3.0/lib/shared/appengine-local-runtime-shared.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-1.3.0/lib/impl/appengine-api-stubs.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-1.3.0/lib/impl/appengine-local-runtime.jar
echo CLASSPATH=$CLASSPATH
export CLASSPATH
