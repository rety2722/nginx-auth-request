FROM nginx:1.27-alpine

# Copy the custom Nginx configuration
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 