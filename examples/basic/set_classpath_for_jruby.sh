# source set_classpath_for_jruby.sh

PROJ_HOME=$(cd $(dirname $0);pwd)
GAE_VER=1.3.0
APPENGINE_SDK_GEM=/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-$GAE_VER

CLASSPATH=""
CLASSPATH=$CLASSPATH:$PROJ_HOME/WEB-INF/lib/appengine-api-1.0-sdk-$GAE_VER.jar
CLASSPATH=$CLASSPATH:$PROJ_HOME/WEB-INF/lib/appengine-api-labs-$GAE_VER.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-$GAE_VER/lib/shared/appengine-local-runtime-shared.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-$GAE_VER/lib/impl/appengine-api-stubs.jar
CLASSPATH=$CLASSPATH:$APPENGINE_SDK_GEM/appengine-java-sdk-$GAE_VER/lib/impl/appengine-local-runtime.jar
echo CLASSPATH=$CLASSPATH
export CLASSPATH
