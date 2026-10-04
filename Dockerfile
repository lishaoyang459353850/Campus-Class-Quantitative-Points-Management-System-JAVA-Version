# ==========================================================================
# 校园班级量化积分管理系统 —— 生产镜像
# 基础镜像：eclipse-temurin 17（Java 17 LTS）
# 构建方式：先在本机执行 mvn -DskipTests package 得到 target/school-points.jar，
#          再用本 Dockerfile 打包镜像（无需在容器内重新编译，构建更快）。
# ==========================================================================
FROM eclipse-temurin:17-jre

LABEL maintainer="school-points" \
      description="校园班级量化积分管理系统"

# 时区设置为中国标准时间，避免日志与业务时间偏差
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

# 运行所需目录：日志、上传文件、数据
RUN mkdir -p /app/logs /app/data/upload

# 拷贝已编译好的可执行 jar
COPY target/school-points.jar /app/school-points.jar

# 生产环境推荐用 prod 配置；敏感项通过 docker-compose 的环境变量注入
ENV SPRING_PROFILES_ACTIVE=prod \
    JAVA_OPTS="-Xms512m -Xmx1024m -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/school-points.jar"]
