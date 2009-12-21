module Vanity
  module Store
    # @since 1.3.0
    class ActiveRecord
      def initialize(connection = nil)
        @connection = connection
      end

      def connection
        @connection ||= ::ActiveRecord::Base.connection
      end

      def table_name
        @table_name ||= "vanity_hash"
      end

      def get(key)
        select_value("SELECT value FROM #{table_name} WHERE key=?", key)
      end
      alias :[] :get

      def setnx(key, value)
        execute "INSERT INTO #{table_name} (key, value) VALUES (?,?)", key, value rescue nil
      end

      def set(key, value)
        execute("INSERT INTO #{table_name} (key, value) VALUES (?,?)", key, value) rescue
        execute("UPDATE #{table_name} SET value=? WHERE key=?", value, key)
      end
      alias :[]= :set

      def del(*keys)
        execute "DELETE FROM #{table_name} WHERE key IN (?)", keys.flatten
      end

      def incrby(key, incr)
        if value = get(key)
          execute("UPDATE #{table_name} SET value=? WHERE key=?", value.to_i + incr, key) or incrby(key, incr)
        else
          execute("INSERT INTO #{table_name} (key, value) VALUES (?,?)", key, incr) or incrby(key, incr)
        end
      end

      def incr(key)
        incrby key, 1
      end

      def mget(keys)
        hash = select_rows("SELECT key, value FROM #{table_name} WHERE key IN (?)", keys).
          inject({}) { |hash, (key, value)| hash.update(key=>value) }
        keys.map { |key| hash[key] }
      end

      def exists(key)
        select_value("SELECT 1 FROM #{table_name} WHERE key = ?", key) && true
      end

      def keys(pattern)
        select_values("SELECT key FROM #{table_name} WHERE key LIKE ?", pattern.gsub("*", "%"))
      end

      def flushdb
        execute "DELETE FROM #{table_name}"
      end

      def sismember(key, value)
        y = get(key)
        y ? YAML.load(y).member?(value.to_s) : false
      end

      def sadd(key, value)
        y = get(key)
        s = Set.new(y ? YAML.load(y) : [])
        s.add value.to_s
        set key, YAML.dump(s.to_a)
      end

      def scard(key)
        y = get(key)
        y ? YAML.load(y).size : 0
      end
    protected

      def bind(statement, *args)
        ::ActiveRecord::Base.send(:sanitize_sql_array, [statement] + args)
      end

      def select_value(statement, *args)
        connection.select_value(bind(statement, *args))
      end

      def select_values(statement, *args)
        connection.select_values(bind(statement, *args))
      end

      def select_rows(statement, *args)
        connection.select_rows(bind(statement, *args))
      end

      def execute(statement, *args)
        connection.execute bind(statement, *args)
      end

    end
  end
end
