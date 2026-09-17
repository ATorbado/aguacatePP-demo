package com.atorbado.vialidadinvernal;

import com.atorbado.vialidadinvernal.config.RuntimeConfiguration;
import com.atorbado.vialidadinvernal.delivery.MessageDelivery;
import com.atorbado.vialidadinvernal.delivery.PreviewMessageDelivery;
import com.atorbado.vialidadinvernal.storage.WorkspacePolicy;
import java.io.IOException;

public record ApplicationServices(WorkspacePolicy workspace, MessageDelivery delivery) {
    public static ApplicationServices create(RuntimeConfiguration configuration) throws IOException {
        WorkspacePolicy workspace = new WorkspacePolicy(configuration.workspaceRoot());
        MessageDelivery delivery = new PreviewMessageDelivery(workspace);
        return new ApplicationServices(workspace, delivery);
    }
}
